// RatingApiService 를 대신하는 Fake.
//
// 조회만 흉내내지 않고 **등록·수정·삭제가 목록에 반영되게** 해 두었다.
// 8주차에 v7 계약으로 맞췄다. 등록·수정은 Rating 객체를 돌려주고, 쓰기 요청에
// memberId 가 들어가지 않으며, 실패 code 가 도메인별(RATING403_1 …)이다.
import 'package:dio/dio.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/services/rating_api_service.dart';

import 'movie_log_fixtures.dart';

enum FakeRatingMode {
  /// 평점이 있는 회원
  success,

  /// 평점이 없는 회원 (빈 배열)
  empty,

  /// memberId 형식 오류 (400)
  badRequest,

  /// 존재하지 않는 회원 (404)
  notFound,

  /// 통신 실패 (status 없는 DioException)
  failure,
}

/// 쓰기 요청(등록·수정·삭제)이 돌려줄 결과.
enum FakeWriteMode {
  success,

  /// 400 COMMON400 — 별점 범위. 같은 화면에서 값만 고치면 되는 오류다.
  badRequest,

  /// 403 RATING403_1 — 남의 평점. 인가 실패라 로그아웃 대상이 아니다.
  forbidden,

  /// 404 RATING404_1 / MEMBER404_1 — 없는 평점(수정·삭제) 또는 없는 회원(등록).
  notFound,

  /// 409 RATING409_1 — 이미 평점을 남긴 영화.
  conflict,

  /// 401 AUTH401_4 — Token 만료. 세션을 정리해야 하는 유일한 모드다.
  expired,

  /// 통신 실패. **401 이 아니다.** 로그아웃으로 이어지면 안 된다.
  failure,
}

/// 수정 요청 한 번의 기록.
class UpdateCall {
  const UpdateCall({
    required this.ratingId,
    required this.score,
    required this.comment,
    required this.body,
  });

  final int ratingId;
  final int score;
  final String? comment;

  /// 실제로 보낸 JSON. comment key 가 빠지지 않는지 확인할 때 쓴다.
  final Map<String, dynamic> body;
}

class FakeRatingApiService extends RatingApiService {
  FakeRatingApiService({
    this.mode = FakeRatingMode.success,
    this.createMode = FakeWriteMode.success,
    this.updateMode = FakeWriteMode.success,
    this.deleteMode = FakeWriteMode.success,
    this.delay = Duration.zero,
    this.failingDeleteIds = const {},
    List<RatingDto>? ratings,
  })  : ratings = ratings ??
            [
              fakeRating(1),
              fakeRating(2, movieId: 680, score: 4, comment: '다시 봐도 좋다'),
              // comment 가 null 인 평점. 화면에서 후기 줄을 그리지 않아야 한다.
              fakeRating(3, movieId: 13, score: 3, comment: null),
            ],
        super(Dio(), Dio());

  FakeRatingMode mode;
  FakeWriteMode createMode;
  FakeWriteMode updateMode;
  FakeWriteMode deleteMode;
  Duration delay;

  /// 이 id 의 삭제만 실패시킨다. (다중 삭제에서 일부만 실패하는 상황)
  Set<int> failingDeleteIds;

  List<RatingDto> ratings;

  /// 어떤 memberId 로 몇 번 물었는지. (공개 조회)
  final List<int> fetchCalls = [];

  /// 등록 요청 body 기록. memberId 가 섞여 들어가지 않는지 확인한다.
  final List<Map<String, dynamic>> createCalls = [];
  final List<UpdateCall> updateCalls = [];
  final List<int> deleteCalls = [];

  int _nextRatingId = 100;

  @override
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    fetchCalls.add(memberId);
    await _wait();

    final options = RequestOptions(path: '/v7/members/$memberId/ratings');

    switch (mode) {
      case FakeRatingMode.success:
        // 호출한 쪽이 목록을 들고 있는 동안 Fake 가 바뀌어도 영향이 없도록 복사본.
        return List.of(ratings);
      case FakeRatingMode.empty:
        return const [];
      case FakeRatingMode.badRequest:
        return throw _legacyError(
          options,
          400,
          'Validation failed (numeric string is expected)',
        );
      case FakeRatingMode.notFound:
        return throw _legacyError(options, 404, '존재하지 않는 유저입니다.');
      case FakeRatingMode.failure:
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'fake network failure',
        );
    }
  }

  /// v7: 경로에 memberId 가 없고, 성공 응답이 Rating 객체다.
  @override
  Future<RatingDto> createRating(CreateRatingRequest request) async {
    createCalls.add(request.toJson());
    await _wait();

    _throwIfNeeded(createMode, '/v7/ratings', isWriteOnExisting: false);

    final created = RatingDto(
      ratingId: _nextRatingId++,
      movieId: request.movieId,
      score: request.score,
      comment: request.comment,
      createdAt: DateTime.parse('2026-11-16T09:00:00.000Z'),
    );
    ratings = [created, ...ratings];
    return created;
  }

  @override
  Future<RatingDto> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    final body = UpdateRatingRequest(score: score, comment: comment).toJson();
    updateCalls.add(
      UpdateCall(
        ratingId: ratingId,
        score: score,
        comment: comment,
        body: body,
      ),
    );
    await _wait();

    _throwIfNeeded(
      updateMode,
      '/v7/ratings/$ratingId',
      isWriteOnExisting: true,
    );

    final current = ratings.firstWhere(
      (rating) => rating.ratingId == ratingId,
      orElse: () => fakeRating(ratingId),
    );
    final updated = RatingDto(
      ratingId: ratingId,
      movieId: current.movieId,
      score: body['score'] as int,
      // 서버와 같게, 보내지 않은 comment 는 null 로 덮인다.
      comment: body['comment'] as String?,
      createdAt: current.createdAt,
    );

    ratings = [
      for (final rating in ratings)
        if (rating.ratingId == ratingId) updated else rating,
    ];
    return updated;
  }

  @override
  Future<void> deleteRating(int ratingId) async {
    deleteCalls.add(ratingId);
    await _wait();

    final path = '/v7/ratings/$ratingId';
    if (failingDeleteIds.contains(ratingId)) {
      throw commonError(
        RequestOptions(path: path),
        404,
        'RATING404_1',
        '해당 평점을 찾을 수 없습니다.',
      );
    }
    _throwIfNeeded(deleteMode, path, isWriteOnExisting: true);

    ratings = ratings.where((rating) => rating.ratingId != ratingId).toList();
  }

  Future<void> _wait() async {
    if (delay > Duration.zero) await Future.delayed(delay);
  }

  /// 쓰기 요청의 실패 모드를 v7 공통 형식으로 던진다.
  ///
  /// 같은 404 라도 등록은 "없는 회원"(MEMBER404_1),
  /// 수정·삭제는 "없는 평점"(RATING404_1) 이다.
  void _throwIfNeeded(
    FakeWriteMode writeMode,
    String path, {
    required bool isWriteOnExisting,
  }) {
    final options = RequestOptions(path: path);

    switch (writeMode) {
      case FakeWriteMode.success:
        return;
      case FakeWriteMode.badRequest:
        throw commonError(options, 400, 'COMMON400', '별점은 5점 이하여야 합니다.');
      case FakeWriteMode.forbidden:
        throw commonError(
          options,
          403,
          'RATING403_1',
          '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.',
        );
      case FakeWriteMode.notFound:
        throw commonError(
          options,
          404,
          isWriteOnExisting ? 'RATING404_1' : 'MEMBER404_1',
          isWriteOnExisting ? '해당 평점을 찾을 수 없습니다.' : '해당 회원을 찾을 수 없습니다.',
        );
      case FakeWriteMode.conflict:
        throw commonError(options, 409, 'RATING409_1', '이미 이 영화에 평점을 남기셨습니다.');
      case FakeWriteMode.expired:
        throw commonError(options, 401, 'AUTH401_4', '만료된 토큰입니다.');
      case FakeWriteMode.failure:
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'fake network failure',
        );
    }
  }

  /// 공개 평점 조회 실패는 v5 때부터 쓰던 모양(`message`, `error`, `statusCode`)이다.
  DioException _legacyError(
    RequestOptions options,
    int statusCode,
    String message,
  ) {
    return DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(
        requestOptions: options,
        statusCode: statusCode,
        data: {
          'message': message,
          'error': statusCode == 404 ? 'Not Found' : 'Bad Request',
          'statusCode': statusCode,
        },
      ),
    );
  }
}

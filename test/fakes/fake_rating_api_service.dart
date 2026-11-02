// RatingApiService 를 대신하는 Fake.
import 'package:dio/dio.dart';
import 'package:movielog/data/models/rating_dto.dart';
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

class FakeRatingApiService extends RatingApiService {
  FakeRatingApiService({
    this.mode = FakeRatingMode.success,
    this.delay = Duration.zero,
    List<RatingDto>? ratings,
  })  : ratings = ratings ??
            [
              fakeRating(1),
              fakeRating(2, movieId: 680, score: 4, comment: '다시 봐도 좋다'),
              // comment 가 null 인 평점. 화면에서 후기 줄을 그리지 않아야 한다.
              fakeRating(3, movieId: 13, score: 3, comment: null),
            ],
        super(Dio());

  FakeRatingMode mode;
  Duration delay;
  List<RatingDto> ratings;

  /// 어떤 memberId 로 몇 번 물었는지.
  final List<int> fetchCalls = [];

  @override
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    fetchCalls.add(memberId);
    if (delay > Duration.zero) await Future.delayed(delay);

    final options = RequestOptions(path: '/v5/members/$memberId/ratings');

    switch (mode) {
      case FakeRatingMode.success:
        return ratings;
      case FakeRatingMode.empty:
        return const [];
      case FakeRatingMode.badRequest:
        throw _error(options, 400, 'Validation failed (numeric string is expected)');
      case FakeRatingMode.notFound:
        throw _error(options, 404, '존재하지 않는 유저입니다.');
      case FakeRatingMode.failure:
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'fake network failure',
        );
    }
  }

  /// v5 의 실패 응답 모양(`message`, `error`, `statusCode`)을 그대로 흉내낸다.
  DioException _error(RequestOptions options, int statusCode, String message) {
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

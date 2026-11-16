// lib/data/services/rating_api_service.dart
import 'package:dio/dio.dart';

import '../../core/network/api_error.dart';
import '../models/common_response.dart';
import '../models/rating_dto.dart';
import '../models/rating_request.dart';

/// 평점 조회·등록·수정·삭제를 담당하는 Service.
///
/// 8주차에 v6 → v7 로 전환했다. **URL 수정만이 아니다.** Authorization Header,
/// 성공 status, result 타입, 오류 code 가 함께 바뀌었다.
///
/// | 동작 | v6 | v7 |
/// | --- | --- | --- |
/// | 등록 | `POST /v6/members/{id}/ratings` | `POST /v7/ratings` |
/// | 수정 | `PATCH /v6/members/{id}/ratings/{rid}` | `PATCH /v7/ratings/{rid}` |
/// | 삭제 | `DELETE` 같은 경로, 204 + 본문 없음 | `DELETE /v7/ratings/{rid}`, 200 + result null |
/// | 사용자 식별 | path 의 memberId | `Authorization: Bearer ...` |
/// | 등록/수정 result | ID? / null | Rating 객체 |
/// | 도메인 오류 | COMMON 계열 | AUTH / MEMBER / RATING 계열 |
///
/// **memberId 를 body 나 query 로 옮기지 않았다.** v7 보호 요청에는 보낼 자리가
/// 없다. 값을 받지 않는 것이 그 값을 조작당하지 않는 방법이다.
///
/// Client 를 **두 개** 받는다. 쓰기는 보호 API 로 바뀌었지만 유저별 평점 조회는
/// 로그인 없이도 호출할 수 있는 공개 API 로 남았기 때문이다. 어떤 Client 로
/// 보낼지는 Service 가 메서드별로 정하므로 ViewModel 코드는 바뀌지 않는다.
class RatingApiService {
  RatingApiService(this._publicDio, this._authDio);

  /// 공개 조회용. [AuthInterceptor] 가 없어 Token 이 붙지 않는다.
  final Dio _publicDio;

  /// 보호 쓰기용. 요청마다 Interceptor 가 `Authorization` 을 붙인다.
  final Dio _authDio;

  /// GET /v7/members/{memberId}/ratings — 공개 조회.
  ///
  /// 성공 응답은 Wrapper 없이 평점 배열이 그대로 온다. 평점이 없는 회원은
  /// 빈 배열이다. (실패가 아니다)
  ///
  /// v7 로그인·내 정보 응답에는 memberId 가 없으므로, 이 메서드는 **memberId 를
  /// 이미 아는 경우에만** 쓸 수 있다. (이 앱에서는 이번 세션에 회원가입을 한
  /// 경우다) Token 기반 '내 평점 전체 GET' 은 아직 명세에 없다.
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    final response = await _publicDio.get('/v7/members/$memberId/ratings');
    return parseRatingList(response.data);
  }

  /// POST /v7/ratings — 성공은 201 + result 에 **Rating 객체**.
  ///
  /// v6 에서는 result 계약이 불확실해 status 만 보고 목록을 다시 조회했다.
  /// v7 은 저장된 평점을 그대로 내려주므로, 등록 직후 재조회 없이 그 객체로
  /// 화면을 갱신한다. body 에 memberId 를 넣지 않는다.
  Future<RatingDto> createRating(CreateRatingRequest request) async {
    final response = await _authDio.post('/v7/ratings', data: request.toJson());
    return parseRatingResult(response.data);
  }

  /// PATCH /v7/ratings/{ratingId} — 성공은 200 + result 에 Rating 객체.
  ///
  /// **PATCH 이지만 부분 수정이 아니라 전체 교체다.** comment 를 생략하면
  /// 서버에 null 로 전달되어 기존 후기가 지워진다. 그래서 [UpdateRatingRequest]
  /// 가 score 와 comment 를 항상 함께 보내고, 수정 Dialog 는 열 때 기존 두 값을
  /// 모두 채워 둔다.
  Future<RatingDto> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    final response = await _authDio.patch(
      '/v7/ratings/$ratingId',
      data: UpdateRatingRequest(score: score, comment: comment).toJson(),
    );
    return parseRatingResult(response.data);
  }

  /// DELETE /v7/ratings/{ratingId} — 성공은 **204 가 아니라 200** + result null.
  ///
  /// v6 의 204 는 본문이 없어 공통 응답 형식을 실을 수 없었다. v7 은 삭제도
  /// 같은 형식을 유지하려고 200 을 쓴다. 그래서 `statusCode != 204` 를 실패로
  /// 보던 v6 검사를 그대로 두면 **성공한 삭제가 실패로 보인다.**
  Future<void> deleteRating(int ratingId) async {
    final response = await _authDio.delete('/v7/ratings/$ratingId');

    if (response.statusCode != 200) {
      throw StateError('예상하지 못한 삭제 응답: ${response.statusCode}');
    }
  }
}

/// 등록·수정 응답(공통 Wrapper)에서 Rating 한 건을 꺼낸다.
RatingDto parseRatingResult(Object? data) {
  if (data is! Map<String, dynamic>) {
    throw StateError('평점 응답 형식이 올바르지 않습니다.');
  }

  final common = CommonResponse<RatingDto>.fromJson(
    data,
    (value) => RatingDto.fromJson(value as Map<String, dynamic>),
  );

  final rating = common.result;
  if (rating == null) throw StateError('평점 result가 없습니다.');

  return rating;
}

/// 공개 조회 응답(Wrapper 없는 배열)을 파싱한다.
List<RatingDto> parseRatingList(Object? data) {
  if (data is! List) throw StateError('평점 목록 응답은 배열이어야 합니다.');

  return data
      .map((item) => RatingDto.fromJson(item as Map<String, dynamic>))
      .toList();
}

/// 평점 조회 실패를 화면에 보여줄 문구로 바꾼다.
///
/// 조회는 공개 API 라 Token 과 무관하다. 그래서 401 분기가 없다.
/// (400 = memberId 형식 오류, 404 = 없는 회원, 그 밖 = 네트워크·서버 오류)
String writeMyRatingsErrorMessage(DioException error) {
  final status = error.response?.statusCode;
  if (status == 400) return 'memberId 형식을 다시 확인해 주세요.';
  if (status == 404) return '존재하지 않는 회원입니다.';
  return '평점을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.';
}

/// 평점 쓰기(등록·수정·삭제) 실패를 화면 문구로 바꾼다.
///
/// v7 은 code 가 도메인별로 갈라져 **무엇이 잘못됐는지 code 만으로 구분된다.**
/// 세션 만료(`AUTH401_2/3/4`)는 여기서 문구를 만들지 않는다. 그쪽은 안내가
/// 아니라 세션 정리가 필요한 상태이므로 ViewModel 이 따로 처리한다.
String writeErrorMessage(DioException error) {
  final code = apiErrorCode(error);

  return switch (code) {
    // 인증은 됐지만 남이 작성한 평점이다. 로그아웃할 일이 아니다.
    'RATING403_1' => '본인이 작성한 평점만 수정하거나 삭제할 수 있어요.',
    'RATING404_1' => '이미 삭제된 평점이에요. 목록을 새로고침합니다.',
    'RATING409_1' => '이미 이 영화에 평점을 남겼어요. 기존 기록을 확인해 주세요.',
    'MEMBER404_1' => '회원 정보를 찾을 수 없어요.',
    // 별점 범위 같은 입력 검증 실패는 서버 문구가 이미 구체적이다.
    'COMMON400' || 'COMMON4001' =>
      apiErrorMessage(error) ?? '입력값을 다시 확인해 주세요.',
    _ => apiErrorMessage(error) ?? '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.',
  };
}

/// 쓰기 실패 뒤에 목록을 다시 조회해야 하는 오류인지.
///
/// 403(남의 평점) · 404(없는 평점)는 **화면에 남은 목록이 서버 상태와 어긋났다**는
/// 신호이므로 다시 맞춘다. 400(별점 범위) · 409(중복 등록)는 같은 화면에서 값만
/// 고치거나 기존 기록을 확인하면 되는 오류라 재조회가 필요 없다.
bool shouldRefreshAfterRatingError(DioException error) {
  final code = apiErrorCode(error);
  if (code != null) return code == 'RATING403_1' || code == 'RATING404_1';

  // body 가 공통 형식이 아니면(프록시 오류 등) status 로 같은 판단을 한다.
  final status = error.response?.statusCode;
  return status == 403 || status == 404;
}

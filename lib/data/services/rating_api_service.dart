// lib/data/services/rating_api_service.dart
import 'package:dio/dio.dart';

import '../models/common_response.dart';
import '../models/rating_dto.dart';
import '../models/rating_request.dart';

/// 평점 조회·등록·수정·삭제를 담당하는 Service.
///
/// 네 Method 의 **성공 응답 계약이 모두 다르다.** v6 이라고 전부 공통 응답으로
/// 파싱하면 조회(직접 배열)와 삭제(본문 없음)에서 깨진다.
///
/// | 동작 | 요청                                        | 성공            |
/// | --- | ------------------------------------------- | --------------- |
/// | 조회 | GET    /v6/members/{id}/ratings             | 200 + 직접 배열   |
/// | 등록 | POST   /v6/members/{id}/ratings             | 201 + 공통 응답   |
/// | 수정 | PATCH  /v6/members/{id}/ratings/{ratingId}  | 200 + result null |
/// | 삭제 | DELETE /v6/members/{id}/ratings/{ratingId}  | 204 + 본문 없음   |
class RatingApiService {
  RatingApiService(this._dio);

  final Dio _dio;

  /// GET /v6/members/{memberId}/ratings
  ///
  /// 성공 응답은 Wrapper 없이 평점 배열이 그대로 온다.
  /// 평점이 없는 회원은 빈 배열을 돌려준다. (실패가 아니다)
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    final response = await _dio.get('/v6/members/$memberId/ratings');
    final list = response.data as List<dynamic>;
    return list
        .map((item) => RatingDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// POST /v6/members/{memberId}/ratings — 성공은 201.
  ///
  /// Swagger 설명에는 `result` 가 ratingId 숫자라고 적혀 있지만 같은 응답
  /// schema 의 예시는 null 이다. 계약이 확정되기 전에는 `result!` 로 강제
  /// 캐스팅하지 않고, **등록 성공 여부만 status 로 판단**한 뒤 목록을 다시 조회해
  /// 실제 저장 결과를 확인한다.
  Future<void> createRating({
    required int memberId,
    required CreateRatingRequest request,
  }) async {
    final response = await _dio.post(
      '/v6/members/$memberId/ratings',
      data: request.toJson(),
    );

    if (response.statusCode != 201) {
      throw StateError('예상하지 못한 등록 응답: ${response.statusCode}');
    }
  }

  /// PATCH /v6/members/{memberId}/ratings/{ratingId} — 성공은 200 + result null.
  ///
  /// 돌려줄 데이터가 없으므로 응답 본문을 파싱하지 않는다.
  /// comment 를 생략하면 기존 후기가 null 로 덮이는 계약이라
  /// [UpdateRatingRequest] 가 score 와 comment 를 **항상 함께** 보낸다.
  Future<void> updateRating({
    required int memberId,
    required int ratingId,
    required UpdateRatingRequest request,
  }) async {
    await _dio.patch(
      '/v6/members/$memberId/ratings/$ratingId',
      data: request.toJson(),
    );
  }

  /// DELETE /v6/members/{memberId}/ratings/{ratingId} — 성공은 204.
  ///
  /// 204 는 본문이 없다. `response.data as Map` 을 호출하면 성공인데도
  /// 파싱 오류가 난다.
  Future<void> deleteRating({
    required int memberId,
    required int ratingId,
  }) async {
    final response = await _dio.delete(
      '/v6/members/$memberId/ratings/$ratingId',
    );

    if (response.statusCode != 204) {
      throw StateError('예상하지 못한 삭제 응답: ${response.statusCode}');
    }
  }
}

/// 평점 조회 실패를 화면에 보여줄 문구로 바꾼다.
///
/// 조회는 v5 때부터 있던 API 라 실패 body 가 공통 형식일 수도, v5 형식
/// (`{message, error, statusCode}`)일 수도 있다. 그래서 서버 문구를 그대로
/// 띄우지 않고 status 별로 우리 문구를 정해 둔다.
/// (400 = memberId 형식 오류, 404 = 없는 회원, 그 밖 = 네트워크·서버 오류)
String writeMyRatingsErrorMessage(DioException error) {
  final status = error.response?.statusCode;
  if (status == 400) return 'memberId 형식을 다시 확인해 주세요.';
  if (status == 404) return '존재하지 않는 회원입니다.';
  return '평점을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.';
}

/// 평점 쓰기(등록·수정·삭제) 실패를 화면 문구로 바꾼다.
///
/// 같은 `COMMON404` 라도 등록에서는 "존재하지 않는 유저입니다.",
/// 수정·삭제에서는 "존재하지 않는 평점입니다." 다. code 만 보고 우리 문구를
/// 새로 만들면 이 차이를 놓치므로 **서버 `message` 를 그대로** 쓴다.
String writeErrorMessage(DioException error) {
  return commonErrorOf(error.response?.data)?.message ??
      '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.';
}

/// 쓰기 실패 뒤에 목록을 다시 조회해야 하는 오류인지.
///
/// 403(남의 평점) · 404(없는 평점)는 **화면에 남은 목록이 서버 상태와 어긋났다**는
/// 신호이므로 다시 조회해 맞춘다. 400(별점 범위) · 409(중복 등록)는 같은 화면에서
/// 값만 고치거나 다시 시도하면 되는 오류라 재조회가 필요 없다.
bool shouldRefreshAfterRatingError(DioException error) {
  final code = commonErrorOf(error.response?.data)?.code;
  if (code != null) return code == 'COMMON403' || code == 'COMMON404';

  // body 가 공통 형식이 아니면(프록시 오류 등) status 로 같은 판단을 한다.
  final status = error.response?.statusCode;
  return status == 403 || status == 404;
}

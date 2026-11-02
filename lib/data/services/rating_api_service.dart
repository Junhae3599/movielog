// lib/data/services/rating_api_service.dart
import 'package:dio/dio.dart';

import '../models/rating_dto.dart';

/// 회원이 남긴 평점을 조회하는 Service.
///
/// 6주차 v5 에는 조회(GET)만 있다. 평점 등록·수정·삭제는 v6 부터이므로
/// 이번 주차에는 쓰기 요청을 보내지 않는다.
class RatingApiService {
  RatingApiService(this._dio);

  final Dio _dio;

  /// GET /v5/members/{memberId}/ratings
  ///
  /// 평점이 없는 회원은 빈 배열을 돌려준다. (실패가 아니다)
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    final response = await _dio.get('/v5/members/$memberId/ratings');
    final list = response.data as List<dynamic>;
    return list
        .map((item) => RatingDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

/// 평점 조회 실패를 화면에 보여줄 문구로 바꾼다.
///
/// v5 는 공통 응답 형식이 없고 실패만 `{message, error, statusCode}` 로 온다.
/// 서버 문구를 그대로 띄우지 않고 status 별로 우리 문구를 정해 둔다.
/// (400 = memberId 형식 오류, 404 = 없는 회원, 그 밖 = 네트워크·서버 오류)
String writeMyRatingsErrorMessage(DioException error) {
  final status = error.response?.statusCode;
  if (status == 400) return 'memberId 형식을 다시 확인해 주세요.';
  if (status == 404) return '존재하지 않는 회원입니다.';
  return '평점을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.';
}

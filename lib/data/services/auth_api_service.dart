// lib/data/services/auth_api_service.dart
import 'package:dio/dio.dart';

import '../models/common_response.dart';
import '../models/login_models.dart';

/// 로그인 API 전용 Service.
///
/// **공개용 Client 를 받는다.** 로그인은 Token 을 받으러 가는 요청이므로
/// 보낼 Token 이 아직 없다. 보호용 Client 로 보내면 만료된 옛 Token 이 실려
/// 나가고, 서버가 그것을 먼저 거부할 수도 있다.
class AuthApiService {
  AuthApiService(this._publicDio);

  final Dio _publicDio;

  /// POST /v7/auth/login — 성공은 200 + 공통 응답의 `result` 에 nickname/accessToken.
  ///
  /// 실패(401 `AUTH401_1`)는 [DioException] 으로 올라가고, 그것을 Form 오류로
  /// 번역하는 일은 ViewModel 이 한다. Service 는 HTTP 와 DTO 변환만 담당한다.
  Future<LoginResult> login(LoginRequest request) async {
    final response = await _publicDio.post(
      '/v7/auth/login',
      data: request.toJson(),
    );

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('로그인 응답 형식이 올바르지 않습니다.');
    }

    final common = CommonResponse<LoginResult>.fromJson(
      data,
      (value) => LoginResult.fromJson(value as Map<String, dynamic>),
    );

    final result = common.result;
    // 2xx 인데 result 가 없으면 저장할 Token 이 없다. 성공으로 보면
    // Token 없이 signedIn 이 되어 모든 보호 요청이 401 을 받는다.
    if (result == null) throw StateError('로그인 result가 없습니다.');

    return result;
  }
}

// lib/data/services/sign_up_service.dart
import 'package:dio/dio.dart';

import '../models/check_result.dart';
import '../models/common_response.dart';
import '../models/create_member_request.dart';
import '../models/sign_up_models.dart';

/// 회원가입 화면이 쓰는 Service. (6주차 `MemberCheckService` 를 이어받았다)
///
/// 중복 확인 GET 두 개와 회원가입 POST 하나를 담당한다. 같은 화면이 쓰는 같은
/// 서버의 API 라서 Service 를 둘로 나누지 않았다.
///
/// HTTP 요청과 DTO 변환만 담당한다. "지금 버튼을 누를 수 있는지",
/// "어떤 문구를 보여줄지" 같은 화면 정책은 ViewModel 의 책임이다.
///
/// 상태를 갖지 않으므로(stateless) 여러 화면이 같은 인스턴스 하나를 공유한다.
class SignUpService {
  SignUpService(this._dio);

  final Dio _dio;

  /// GET /v6/members/nickname/{nickname}
  ///
  /// 성공 응답은 v6 에서도 Wrapper 없이 `{"available": true}` 가 그대로 온다.
  /// (실패만 공통 응답으로 감싸진다)
  ///
  /// 닉네임은 경로에 그대로 들어가므로, 공백이나 한글이 섞여도 안전하도록
  /// [Uri.encodeComponent] 로 인코딩한다.
  Future<bool> checkNickname(String nickname) async {
    final encoded = Uri.encodeComponent(nickname.trim());
    final response = await _dio.get('/v6/members/nickname/$encoded');
    return CheckResult.fromJson(response.data as Map<String, dynamic>).available;
  }

  /// GET /v6/members/email/{email}
  Future<bool> checkEmail(String email) async {
    final encoded = Uri.encodeComponent(email.trim());
    final response = await _dio.get('/v6/members/email/$encoded');
    return CheckResult.fromJson(response.data as Map<String, dynamic>).available;
  }

  /// POST /v6/members — 성공은 201 + 공통 응답의 `result` 에 회원 정보.
  ///
  /// 중복 확인을 통과한 직후에도 다른 사용자가 같은 값을 먼저 등록할 수 있다.
  /// 그래서 **이 요청의 409 가 최종 중복 결과**이고, 중복 확인 GET 은 미리
  /// 알려주는 보조 수단일 뿐이다.
  Future<CommonResponse<SignUpResult>> signUp(
    CreateMemberRequest request,
  ) async {
    final response = await _dio.post('/v6/members', data: request.toJson());

    return CommonResponse<SignUpResult>.fromJson(
      response.data as Map<String, dynamic>,
      (value) => SignUpResult.fromJson(value as Map<String, dynamic>),
    );
  }
}

/// 중복 확인 실패를 화면 문구로 바꾼다.
///
/// 통신 자체가 실패한 것(네트워크·타임아웃)과 "이미 사용 중"(`available: false`)은
/// 다른 일이므로, 이 문구는 후자에 쓰지 않는다.
String writeCheckErrorMessage(DioException error) {
  return commonErrorOf(error.response?.data)?.message ??
      '중복 확인에 실패했어요. 다시 시도해 주세요.';
}

/// 회원가입 실패를 화면 문구로 바꾼다.
///
/// v6 Swagger 가 정의한 실패는 두 가지이고, 둘 다 `message` 에 이미 사용자에게
/// 보여줄 수 있는 문장이 들어 있다.
///
/// - `400 COMMON400` — 비밀번호 형식 위반
/// - `409 COMMON409` — 이메일 또는 닉네임 중복
///
/// 그래서 code 별로 우리 문구를 새로 만들지 않고 서버 `message` 를 그대로 쓴다.
/// 서버는 이메일을 먼저 검사하므로, 이메일이 이미 중복이면 닉네임 중복 여부는
/// 알려주지 않는다. (두 오류를 한 번에 보여줄 수 없다는 뜻이다)
String writeSignUpErrorMessage(DioException error) {
  return commonErrorOf(error.response?.data)?.message ??
      '회원가입에 실패했습니다. 잠시 후 다시 시도해 주세요.';
}

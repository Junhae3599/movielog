// lib/data/services/member_check_service.dart
import 'package:dio/dio.dart';

import '../models/check_result.dart';

/// 닉네임·이메일 중복 확인 Service.
///
/// HTTP 요청과 DTO 변환만 담당한다. "지금 버튼을 누를 수 있는지",
/// "어떤 문구를 보여줄지" 같은 화면 정책은 ViewModel 의 책임이다.
///
/// 상태를 갖지 않으므로(stateless) 여러 화면이 같은 인스턴스 하나를 공유한다.
class MemberCheckService {
  MemberCheckService(this._dio);

  final Dio _dio;

  /// GET /v5/members/nickname/{nickname}
  ///
  /// 닉네임은 경로에 그대로 들어가므로, 공백이나 한글이 섞여도 안전하도록
  /// [Uri.encodeComponent] 로 인코딩한다.
  Future<bool> checkNickname(String nickname) async {
    final encoded = Uri.encodeComponent(nickname.trim());
    final response = await _dio.get('/v5/members/nickname/$encoded');
    return CheckResult.fromJson(response.data as Map<String, dynamic>).available;
  }

  /// GET /v5/members/email/{email}
  Future<bool> checkEmail(String email) async {
    final encoded = Uri.encodeComponent(email.trim());
    final response = await _dio.get('/v5/members/email/$encoded');
    return CheckResult.fromJson(response.data as Map<String, dynamic>).available;
  }
}

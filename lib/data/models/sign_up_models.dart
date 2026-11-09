// lib/data/models/sign_up_models.dart

/// 회원가입 성공 응답의 `result` payload.
///
/// 전체 응답은 `CommonResponse<SignUpResult>` 로 파싱하고, 이 클래스는 그
/// `result` 안쪽만 담는다. (Wrapper 와 payload 를 한 클래스에 섞지 않는다)
///
/// [memberId] 는 이번 주차 평점 요청 경로에 들어가는 **학습용 식별자**다.
/// 이 값을 알고 있다는 것은 인증이 아니며, JWT 주차에는 경로에서 memberId 가
/// 사라지고 서버가 Token 으로 회원을 식별한다.
class SignUpResult {
  const SignUpResult({
    required this.memberId,
    required this.email,
    required this.nickname,
  });

  final int memberId;
  final String email;
  final String nickname;

  factory SignUpResult.fromJson(Map<String, dynamic> json) {
    return SignUpResult(
      memberId: (json['memberId'] as num).toInt(),
      email: json['email'] as String,
      nickname: json['nickname'] as String,
    );
  }
}

// lib/data/models/create_member_request.dart

/// 회원가입 요청 body.
///
/// `fromJson` 이 서버 → Dart 방향이라면 [toJson] 은 그 반대인 Dart → 서버
/// 방향이다. 응답 Model([SignUpResult])과 **한 클래스로 합치지 않는다.**
/// 보내는 값(password)과 받는 값(memberId)이 서로 다르기 때문이다.
class CreateMemberRequest {
  const CreateMemberRequest({
    required this.email,
    required this.password,
    required this.nickname,
  });

  final String email;
  final String password;
  final String nickname;

  /// 이메일·닉네임은 앞뒤 공백을 떼고 보낸다.
  ///
  /// 비밀번호는 **trim 하지 않는다.** 사용자가 입력한 공백도 비밀번호의 일부라서
  /// 값을 몰래 바꾸면 "가입은 됐는데 로그인이 안 되는" 상태가 된다.
  /// 앞뒤 공백을 금지할지는 Form validation 에서 명확히 정한다.
  Map<String, dynamic> toJson() => {
        'email': email.trim(),
        'password': password,
        'nickname': nickname.trim(),
      };
}

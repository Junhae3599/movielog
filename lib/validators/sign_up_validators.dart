// lib/validators/sign_up_validators.dart

/// 회원가입 입력 규칙.
///
/// Validator 와 버튼 활성화 조건이 같은 함수를 쓰도록 한곳에 모았다.
/// 규칙이 갈라지면 "버튼은 켜졌는데 누르면 오류가 뜨는" 상태가 생긴다.
abstract final class SignUpValidators {
  static final _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  static const minNicknameLength = 2;
  static const minPasswordLength = 8;

  /// 유효하면 null, 아니면 화면에 보여줄 오류 메시지를 돌려준다.
  static String? nickname(String? value) {
    final nickname = value?.trim() ?? '';

    if (nickname.isEmpty) return '닉네임을 입력해주세요.';
    if (nickname.length < minNicknameLength) {
      return '닉네임은 $minNicknameLength자 이상이어야 합니다.';
    }
    return null;
  }

  static String? email(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) return '이메일을 입력해주세요.';
    if (!_emailPattern.hasMatch(email)) return '올바른 이메일 형식이 아닙니다.';
    return null;
  }

  static String? password(String? value) {
    // 공백도 비밀번호의 일부이므로 trim 하지 않는다.
    final password = value ?? '';

    if (password.isEmpty) return '비밀번호를 입력해주세요.';
    if (password.length < minPasswordLength) {
      return '비밀번호는 $minPasswordLength자 이상이어야 합니다.';
    }
    return null;
  }

  /// 세 입력이 모두 규칙을 통과하고 약관에도 동의했는지.
  static bool canSubmit({
    required String nicknameValue,
    required String emailValue,
    required String passwordValue,
    required bool agreedToTerms,
  }) {
    return agreedToTerms &&
        nickname(nicknameValue) == null &&
        email(emailValue) == null &&
        password(passwordValue) == null;
  }
}

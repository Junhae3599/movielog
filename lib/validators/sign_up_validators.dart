// lib/validators/sign_up_validators.dart

/// 회원가입 입력 규칙.
///
/// Validator 와 버튼 활성화 조건이 같은 함수를 쓰도록 한곳에 모았다.
/// 규칙이 갈라지면 "버튼은 켜졌는데 누르면 오류가 뜨는" 상태가 생긴다.
abstract final class SignUpValidators {
  static final _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  // 서버(v6)의 비밀번호 제약과 같은 규칙을 쓴다. 클라이언트 검증은 **빠른 안내**를
  // 위한 것이며 서버 검증을 대체하지 않는다. 규칙이 서버보다 느슨하면 가입 버튼이
  // 켜졌는데 400 이 돌아오고, 더 엄격하면 가입할 수 있는 값을 막게 된다.
  static final _lowerPattern = RegExp(r'[a-z]');
  static final _upperPattern = RegExp(r'[A-Z]');
  static final _digitPattern = RegExp(r'[0-9]');
  static final _specialPattern = RegExp(r'[!@#$%^&*]');

  static const minNicknameLength = 2;
  static const maxNicknameLength = 12;
  static const minPasswordLength = 8;

  /// 유효하면 null, 아니면 화면에 보여줄 오류 메시지를 돌려준다.
  static String? nickname(String? value) {
    final nickname = value?.trim() ?? '';

    if (nickname.isEmpty) return '닉네임을 입력해주세요.';
    if (nickname.length < minNicknameLength) {
      return '닉네임은 $minNicknameLength자 이상이어야 합니다.';
    }
    if (nickname.length > maxNicknameLength) {
      return '닉네임은 $maxNicknameLength자 이하여야 합니다.';
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
    if (!_lowerPattern.hasMatch(password) ||
        !_upperPattern.hasMatch(password) ||
        !_digitPattern.hasMatch(password) ||
        !_specialPattern.hasMatch(password)) {
      return '비밀번호에 소문자·대문자·숫자·특수문자(!@#\$%^&*)를 각각 하나 이상 넣어주세요.';
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

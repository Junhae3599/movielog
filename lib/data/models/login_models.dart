// lib/data/models/login_models.dart

/// POST /v7/auth/login 의 요청 body.
///
/// 이메일만 trim 한다. 비밀번호는 앞뒤 공백도 사용자가 입력한 값의 일부일 수
/// 있으므로 손대지 않는다. (공백을 지우면 맞는 비밀번호가 틀리게 된다)
class LoginRequest {
  const LoginRequest({required this.email, required this.password});

  final String email;
  final String password;

  Map<String, dynamic> toJson() => {
        'email': email.trim(),
        'password': password,
      };

  /// 비밀번호가 로그·오류 메시지에 섞여 나가지 않도록 toString 을 덮어쓴다.
  ///
  /// `debugPrint('$request')` 한 줄이나 예외 메시지 한 줄로 비밀번호가 콘솔에
  /// 남는 것을 막는다.
  @override
  String toString() => 'LoginRequest(email: $email, password: ***)';
}

/// 로그인 성공 응답의 `result`.
///
/// **memberId 가 없다.** v7 로그인 응답에는 nickname 과 accessToken 둘뿐이다.
/// `json['memberId']` 를 추가하거나 JWT payload 를 디코딩해 꺼내 쓰지 않는다.
/// 명세에 없는 값을 추정하면, 서버가 claim 이름을 바꾸는 순간 앱이 깨진다.
///
/// 이 한계가 "재시작 뒤 내 평점 전체 복원" 을 완료 기능으로 표시하지 않는 이유다.
/// (공개 유저별 평점 GET 은 memberId path 를 요구하는데 그 값을 알 수 없다)
class LoginResult {
  const LoginResult({required this.nickname, required this.accessToken});

  final String nickname;

  /// 서버가 발급한 Access Token(JWT). 저장소에 넣는 즉시 화면에서는 쓰지 않는다.
  final String accessToken;

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    return LoginResult(
      nickname: json['nickname'] as String,
      accessToken: json['accessToken'] as String,
    );
  }

  /// Token 원문이 로그에 남지 않게 한다.
  @override
  String toString() => 'LoginResult(nickname: $nickname, accessToken: ***)';
}

// lib/core/storage/token_storage.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Access Token 을 저장·조회·삭제하는 규칙을 인증 흐름에서 떼어 낸 추상화.
///
/// 로그인·로그아웃·요청 인증 코드가 [FlutterSecureStorage] 라는 **구체적인
/// 구현에 직접 의존하지 않게** 한다. 덕분에 저장 방식을 바꾸거나 테스트용
/// 저장소로 갈아끼워도 인증 로직은 그대로다.
///
/// Token 접근을 한곳에 모으는 효과도 있다. 화면마다 key 문자열을 적으면
/// 한 군데서 오타가 나도 "저장은 됐는데 못 읽는" 상태가 된다.
abstract interface class TokenStorage {
  Future<void> saveAccessToken(String token);

  /// 저장된 Token 이 없으면 null. (아직 로그인하지 않았거나 로그아웃한 상태)
  Future<String?> readAccessToken();

  Future<void> deleteAccessToken();
}

/// 운영체제의 보안 저장 영역(iOS Keychain, Android Keystore)에 Token 을 둔다.
///
/// `shared_preferences` 를 쓰지 않는 이유는 그쪽이 값을 **평문으로** 저장하기
/// 때문이다. 기기 분석이나 백업 추출로 Token 이 그대로 노출될 수 있다.
/// 패키지 공식 문서도 중요한 데이터 저장 용도로는 쓰지 말라고 안내한다.
/// (장르 필터처럼 민감하지 않은 값은 계속 `shared_preferences` 에 둔다)
///
/// **비밀번호는 저장하지 않는다.** 저장하는 것은 서버가 발급한 Access Token
/// 하나뿐이고, 그것도 만료·로그아웃 시 지운다.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage(this._storage);

  /// 앱 이름을 접두사로 붙여 같은 기기의 다른 앱·주차와 섞이지 않게 한다.
  static const _accessTokenKey = 'movielog.access_token';

  final FlutterSecureStorage _storage;

  @override
  Future<void> saveAccessToken(String token) {
    return _storage.write(key: _accessTokenKey, value: token);
  }

  @override
  Future<String?> readAccessToken() {
    return _storage.read(key: _accessTokenKey);
  }

  @override
  Future<void> deleteAccessToken() {
    return _storage.delete(key: _accessTokenKey);
  }
}

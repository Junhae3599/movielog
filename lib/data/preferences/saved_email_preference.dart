// lib/data/preferences/saved_email_preference.dart
import 'package:shared_preferences/shared_preferences.dart';

/// "이메일 저장" 체크박스가 쓰는 저장소. (8주차 Challenge)
///
/// **이메일만 저장한다.** 비밀번호와 Access Token 은 절대 여기에 두지 않는다.
/// `shared_preferences` 는 값을 평문으로 저장하므로, 기기 분석이나 백업 추출로
/// 그대로 읽힌다. 다음 로그인에서 입력 한 번을 줄여 주는 편의값이라
/// 노출돼도 계정이 넘어가지 않는 정보만 담는 것이다.
///
/// Token 은 [SecureTokenStorage] 가 OS 보안 저장소에 넣는다. 두 저장소를
/// 나눈 기준이 "노출됐을 때 무슨 일이 벌어지는가" 다.
class SavedEmailPreference {
  SavedEmailPreference({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const _savedEmailKey = 'movielog.saved_email';

  final SharedPreferencesAsync _preferences;

  /// 저장해 둔 이메일. 체크하지 않았으면 null 이다.
  Future<String?> read() => _preferences.getString(_savedEmailKey);

  Future<void> save(String email) {
    return _preferences.setString(_savedEmailKey, email.trim());
  }

  /// 체크를 해제했거나 로그아웃할 때 지운다.
  Future<void> clear() => _preferences.remove(_savedEmailKey);
}

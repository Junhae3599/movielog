// lib/data/preferences/genre_preference.dart
import 'package:shared_preferences/shared_preferences.dart';

import '../mock_movies.dart';

/// 마지막으로 고른 장르를 기기에 저장한다.
///
/// 중요하지 않은 설정값만 둔다. 토큰이나 개인정보는 여기에 저장하지 않고
/// flutter_secure_storage 를 쓴다.
class GenrePreference {
  GenrePreference({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const _selectedGenreKey = 'selected_genre';

  final SharedPreferencesAsync _preferences;

  /// 저장된 값이 없으면 '전체'(필터 없음)로 본다.
  Future<String> read() async {
    return await _preferences.getString(_selectedGenreKey) ?? allGenresLabel;
  }

  Future<void> save(String genre) async {
    await _preferences.setString(_selectedGenreKey, genre);
  }

  Future<void> clear() async {
    await _preferences.remove(_selectedGenreKey);
  }
}

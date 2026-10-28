// lib/data/preferences/genre_preference.dart
import 'package:shared_preferences/shared_preferences.dart';

/// 마지막으로 고른 장르를 기기에 저장한다.
///
/// 4주차까지는 '드라마' 같은 장르 이름을 저장했지만, 5주차부터 장르는 TMDB 가
/// 내려주는 id/name 쌍이다. 이름은 TMDB 쪽에서 바뀔 수 있으므로 **id 를 저장**한다.
///
/// 중요하지 않은 설정값만 둔다. 토큰이나 개인정보는 여기에 저장하지 않고
/// flutter_secure_storage 를 쓴다.
class GenrePreference {
  GenrePreference({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const _selectedGenreIdsKey = 'selected_genre_ids';

  final SharedPreferencesAsync _preferences;

  /// 저장된 값이 없으면 빈 목록(= 전체)으로 본다.
  Future<List<int>> read() async {
    final raw = await _preferences.getString(_selectedGenreIdsKey);
    if (raw == null || raw.isEmpty) return const [];

    return raw
        .split(',')
        .map(int.tryParse)
        .whereType<int>()
        .toList(growable: false);
  }

  Future<void> save(List<int> genreIds) async {
    await _preferences.setString(
      _selectedGenreIdsKey,
      genreIds.join(','),
    );
  }

  Future<void> clear() async {
    await _preferences.remove(_selectedGenreIdsKey);
  }
}

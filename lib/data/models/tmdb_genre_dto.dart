// lib/data/models/tmdb_genre_dto.dart

/// TMDB 장르 하나.
///
/// 장르 이름을 앱에 하드코딩하고 ID 만 따로 맞추면 TMDB 가 장르를 바꿀 때 어긋난다.
/// Genre API 가 돌려준 id/name 을 그대로 쓴다.
class TmdbGenreDto {
  const TmdbGenreDto({required this.id, required this.name});

  final int id;
  final String name;

  factory TmdbGenreDto.fromJson(Map<String, dynamic> json) {
    return TmdbGenreDto(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '알 수 없는 장르',
    );
  }
}

/// 영화의 `genre_ids` 를 사람이 읽을 장르 이름으로 바꾼다.
///
/// 목록 응답에는 장르 이름이 없고 id 배열만 들어오므로, Genre API 로 받아 둔
/// id/name 쌍을 가지고 화면에서 이름을 찾아 쓴다.
extension TmdbGenreNames on List<TmdbGenreDto> {
  List<String> namesOf(List<int> genreIds) {
    if (isEmpty || genreIds.isEmpty) return const [];

    final byId = {for (final genre in this) genre.id: genre.name};
    return genreIds.map((id) => byId[id]).whereType<String>().toList();
  }
}

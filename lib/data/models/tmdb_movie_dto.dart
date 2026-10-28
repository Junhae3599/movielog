// lib/data/models/tmdb_movie_dto.dart

/// TMDB 영화 한 편의 응답을 담는 DTO.
///
/// JSON 은 snake_case(`poster_path`), Dart 는 lowerCamelCase(`posterPath`) 이므로
/// 각 key 를 명시적으로 연결한다.
///
/// 이 클래스는 자신이 어떻게 화면에 그려지는지 모른다. 값만 담고 동작은 갖지 않는다.
class TmdbMovieDto {
  const TmdbMovieDto({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.releaseDate,
    required this.genreIds,
    required this.voteAverage,
    required this.popularity,
  });

  /// TMDB 가 부여한 영화 식별자.
  ///
  /// 평점을 저장할 때 자체 백엔드의 `movieId` 로 그대로 전달한다.
  /// 배열 index 를 쓰면 정렬·필터가 바뀔 때 다른 영화를 가리키게 된다.
  final int id;

  final String title;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate;
  final List<int> genreIds;
  final double voteAverage;
  final double popularity;

  /// `release_date` 가 "2024-05-17" 또는 빈 문자열로 오므로 연도만 안전하게 꺼낸다.
  /// 값이 없으면 null 을 돌려주고, 화면에서는 출시 연도를 표시하지 않는다.
  int? get releaseYear {
    final date = releaseDate;
    if (date == null || date.length < 4) return null;
    return int.tryParse(date.substring(0, 4));
  }

  factory TmdbMovieDto.fromJson(Map<String, dynamic> json) {
    return TmdbMovieDto(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '제목 없음',
      overview: json['overview'] as String? ?? '',
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      releaseDate: json['release_date'] as String?,
      genreIds: (json['genre_ids'] as List<dynamic>? ?? const [])
          .map((value) => (value as num).toInt())
          .toList(),
      // vote_average 는 8 처럼 정수로 올 수도 있으므로 num 으로 받아 변환한다.
      voteAverage: (json['vote_average'] as num? ?? 0).toDouble(),
      popularity: (json['popularity'] as num? ?? 0).toDouble(),
    );
  }
}

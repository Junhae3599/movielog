// lib/data/movie.dart

/// 영화 한 편의 Mock 데이터.
///
/// 홈·목록·상세가 서로 다른 하드코딩 값을 쓰지 않고 이 모델 하나를 공유한다.
class Movie {
  const Movie({
    required this.id,
    required this.title,
    required this.genres,
    required this.year,
    required this.runtimeMinutes,
    required this.posterAsset,
    required this.rating,
    required this.ratingCount,
    required this.synopsis,
  });

  final int id;
  final String title;

  /// 첫 번째 장르를 대표 장르로 쓴다.
  final List<String> genres;

  final int year;
  final int runtimeMinutes;
  final String posterAsset;

  /// 평균 평점. 읽기 전용으로만 보여준다.
  final double rating;
  final int ratingCount;

  final String synopsis;

  String get genreLabel => genres.join('/');
}

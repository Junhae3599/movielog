// lib/data/models/rating_with_movie.dart
import 'rating_dto.dart';
import 'tmdb_movie_dto.dart';

/// 평점 한 건과 그 영화 정보를 한 쌍으로 묶은 값.
///
/// 평점은 MovieLog 자체 백엔드가, 영화 제목·포스터는 TMDB 가 주인이다.
/// 서로 다른 서버의 응답을 화면이 매번 짝지어 들고 다니지 않도록 여기서 묶는다.
class RatingWithMovie {
  const RatingWithMovie({required this.rating, this.movie});

  final RatingDto rating;

  /// TMDB 에서 찾지 못했거나(404) 조회에 실패하면 null 이다.
  ///
  /// 평점의 주인은 자체 백엔드이므로, 영화 정보를 못 가져와도 평점은 지우지 않고
  /// 제목·포스터만 placeholder 로 보여준다.
  final TmdbMovieDto? movie;
}

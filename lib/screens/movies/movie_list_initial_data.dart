// lib/screens/movies/movie_list_initial_data.dart
import '../../data/movie.dart';

/// 목록 화면이 처음 그려질 때 필요한 값 묶음.
///
/// 영화 목록과 저장된 장르는 서로 의존하지 않으므로 Future.wait 로 함께 불러온다.
class MovieListInitialData {
  const MovieListInitialData({
    required this.movies,
    required this.selectedGenre,
  });

  final List<Movie> movies;
  final String selectedGenre;
}

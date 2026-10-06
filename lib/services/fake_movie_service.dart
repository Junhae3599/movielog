// lib/services/fake_movie_service.dart
import '../data/mock_movies.dart';
import '../data/movie.dart';

/// 서비스가 어떤 결과를 돌려줄지 고르는 값. 네 가지 화면 상태를 확인하는 데 쓴다.
enum FakeMovieServiceMode { success, empty, failure }

/// 실제 서버 대신 Future 를 돌려주는 Mock Service.
///
/// 5주차에 이 클래스를 실제 API Service 로 교체한다. 그때 바뀌는 것은 이 안쪽뿐이고
/// 화면은 `Future<List<Movie>>` 를 받는다는 사실만 알면 된다.
class FakeMovieService {
  const FakeMovieService({
    this.mode = FakeMovieServiceMode.success,
    this.delay = const Duration(milliseconds: 900),
  });

  final FakeMovieServiceMode mode;

  /// Loading 화면이 보이도록 최소 800ms 이상 지연시킨다.
  final Duration delay;

  // TODO(5주차 유저별 평점 조회 API): 이 메서드를 실제 API 호출로 교체한다.
  //  GET /v5/... 응답을 Movie 로 변환해 돌려주면 화면 쪽은 고치지 않아도 된다.
  Future<List<Movie>> fetchMovies() async {
    await Future.delayed(delay);

    switch (mode) {
      case FakeMovieServiceMode.success:
        return movies;
      case FakeMovieServiceMode.empty:
        return const [];
      case FakeMovieServiceMode.failure:
        // 화면에는 이 메시지를 그대로 보여주지 않는다.
        throw Exception('fake network failure');
    }
  }
}

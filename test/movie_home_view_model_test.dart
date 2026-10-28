// MovieHomeViewModel 테스트
//
// "인기 영화 중 앞 5개" 는 홈 화면의 정책이므로 ViewModel 이 결정한다.

import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/view_models/movie_home_view_model.dart';

import 'fakes/fake_tmdb_movie_service.dart';

void main() {
  test('첫 페이지 결과에서 앞 5개만 가져온다', () async {
    final service = FakeTmdbMovieService();
    final viewModel = MovieHomeViewModel(service);

    await viewModel.loadPopular();

    expect(viewModel.popularMovies, hasLength(MovieHomeViewModel.popularLimit));
    expect(viewModel.popularMovies.ids, equals([1, 2, 3, 4, 5]));
    expect(viewModel.status, equals(MovieHomeLoadStatus.success));
    // page 를 더 요청하지 않는다.
    expect(service.popularCallCount, equals(1));
  });

  test('결과가 5개보다 적어도 범위 오류 없이 있는 만큼 보여준다', () async {
    final service = FakeTmdbMovieService(pageSize: 2);
    final viewModel = MovieHomeViewModel(service);

    await viewModel.loadPopular();

    expect(viewModel.popularMovies, hasLength(2));
    expect(viewModel.status, equals(MovieHomeLoadStatus.success));
  });

  test('결과가 없으면 empty', () async {
    final viewModel = MovieHomeViewModel(
      FakeTmdbMovieService(mode: FakeTmdbMode.empty),
    );

    await viewModel.loadPopular();

    expect(viewModel.status, equals(MovieHomeLoadStatus.empty));
  });

  test('실패하면 error 와 안내 문구를 남긴다', () async {
    final viewModel = MovieHomeViewModel(
      FakeTmdbMovieService(mode: FakeTmdbMode.failure),
    );

    await viewModel.loadPopular();

    expect(viewModel.status, equals(MovieHomeLoadStatus.error));
    expect(viewModel.message, isNotNull);
    expect(viewModel.message, isNot(contains('fake network failure')));
  });

  test('이미 불러오는 중이면 요청을 중복해서 보내지 않는다', () async {
    final service = FakeTmdbMovieService(
      delay: const Duration(milliseconds: 50),
    );
    final viewModel = MovieHomeViewModel(service);

    await Future.wait([viewModel.loadPopular(), viewModel.loadPopular()]);

    expect(service.popularCallCount, equals(1));
  });
}

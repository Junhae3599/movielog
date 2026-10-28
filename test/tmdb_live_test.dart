@Tags(['live'])
library;

// 실제 TMDB 서버를 호출해 연동을 확인하는 테스트.
//
// 기본 `flutter test` 에서는 dart_test.yaml 의 tag 설정으로 건너뛴다.
// 확인할 때만 다음으로 실행한다:
//
//   flutter test --tags live
//
// .env 에 TMDB_ACCESS_TOKEN 이 있어야 하고 네트워크가 연결되어 있어야 한다.
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/core/config/tmdb_config.dart';
import 'package:movielog/core/network/tmdb_client.dart';
import 'package:movielog/data/preferences/genre_preference.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/movie_home_view_model.dart';
import 'package:movielog/view_models/movie_list_view_model.dart';

import 'test_helpers.dart';

void main() {
  late TmdbMovieService service;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: '.env');

    service = TmdbMovieService(createTmdbClient());
  });

  setUp(() {
    // flutter_test 의 binding 은 모든 HTTP 요청에 400 을 돌려주는 Mock Client 를
    // HttpOverrides.global 에 끼워 둔다. 실제 서버를 부르려면 그것을 걷어내야 한다.
    // (binding 초기화 '뒤에' 해야 하고, 테스트마다 다시 끼워지므로 setUp 에서 지운다)
    HttpOverrides.global = null;
    useInMemoryPreferences();
  });

  test('.env 에서 Token 을 읽는다', () {
    expect(TmdbConfig.hasAccessToken, isTrue,
        reason: '.env 의 TMDB_ACCESS_TOKEN 이 비어 있습니다');
    // Token 원문은 절대 출력하지 않는다.
    expect(TmdbConfig.accessToken.length, greaterThan(50));
  });

  test('Popular — 200 응답을 DTO 로 바꾸고 인기 5개를 추린다', () async {
    final page = await service.fetchPopular();

    expect(page.page, equals(1));
    expect(page.results, isNotEmpty);
    expect(page.totalPages, greaterThan(1));

    final viewModel = MovieHomeViewModel(service);
    await viewModel.loadPopular();

    expect(viewModel.status, equals(MovieHomeLoadStatus.success));
    expect(viewModel.popularMovies, hasLength(5));

    stdout.writeln('[Popular] total_pages=${page.totalPages} '
        'results=${page.results.length} → 인기 5개');
    for (final movie in viewModel.popularMovies) {
      stdout.writeln('  id=${movie.id} ${movie.title} '
          '(poster=${movie.posterPath != null}) genreIds=${movie.genreIds}');
    }
  });

  test('Genre — 장르 목록을 한국어로 받는다', () async {
    final genres = await service.fetchGenres();

    expect(genres, isNotEmpty);
    // 하드코딩이 아니라 TMDB 가 내려준 id/name 이다.
    expect(genres.any((genre) => genre.id == 878), isTrue);

    stdout.writeln('[Genre] ${genres.length}개');
    for (final genre in genres.take(6)) {
      stdout.writeln('  ${genre.id} ${genre.name}');
    }
  });

  test('Discover — page 1 부터 모아 중복 없이 30개를 만든다', () async {
    final viewModel = MovieListViewModel(
      service,
      genrePreference: GenrePreference(),
    );

    await viewModel.loadInitial();

    expect(viewModel.status, equals(MovieListLoadStatus.success));
    expect(viewModel.movies, hasLength(MovieListViewModel.movieLimit));

    final ids = viewModel.movies.map((movie) => movie.id).toList();
    expect(ids.toSet(), hasLength(ids.length), reason: '중복된 영화 id 가 남아 있다');

    stdout.writeln('[Discover 전체] ${viewModel.movies.length}개 '
        '(고유 id ${ids.toSet().length}개)');
    stdout.writeln('  장르 ${viewModel.genres.length}개 로드됨');
  });

  test('Discover — 장르를 고르면 with_genres 로 다시 조회한다', () async {
    final viewModel = MovieListViewModel(
      service,
      genrePreference: GenrePreference(),
    );

    await viewModel.loadInitial();
    final before = viewModel.movies.map((movie) => movie.id).toSet();

    // 878 = SF
    await viewModel.selectGenres(const [878]);

    expect(viewModel.status, equals(MovieListLoadStatus.success));
    expect(viewModel.movies, isNotEmpty);
    // 응답에 실제로 그 장르가 담겨 돌아온다.
    expect(
      viewModel.movies.every((movie) => movie.genreIds.contains(878)),
      isTrue,
      reason: '로컬 필터가 아니라 with_genres 재조회여야 한다',
    );

    final after = viewModel.movies.map((movie) => movie.id).toSet();
    stdout.writeln('[Discover with_genres=878] ${viewModel.movies.length}개, '
        '전체 목록과 겹치는 영화 ${before.intersection(after).length}개');
    for (final movie in viewModel.movies.take(5)) {
      stdout.writeln('  id=${movie.id} ${movie.title} genreIds=${movie.genreIds}');
    }
  });

  test('"전체" 를 고르면 with_genres 없이 다시 조회한다', () async {
    final viewModel = MovieListViewModel(
      service,
      genrePreference: GenrePreference(),
    );

    await viewModel.selectGenres(const [878]);
    await viewModel.selectGenres(const []);

    expect(viewModel.selectedGenreIds, isEmpty);
    expect(viewModel.movies, hasLength(MovieListViewModel.movieLimit));
  });
}

// MovieListViewModel 테스트
//
// "최대 30개", "중복 제거", "장르 선택 시 page 1 부터 재조회" 는 화면 정책이므로
// Service 가 아니라 이 ViewModel 이 지킨다.

import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/data/preferences/genre_preference.dart';
import 'package:movielog/view_models/movie_list_view_model.dart';

import 'fakes/fake_tmdb_movie_service.dart';
import 'test_helpers.dart';

void main() {
  setUp(useInMemoryPreferences);

  MovieListViewModel build(FakeTmdbMovieService service) =>
      MovieListViewModel(service, genrePreference: GenrePreference());

  group('최대 30개 수집', () {
    test('한 페이지가 20개면 두 페이지를 요청해 정확히 30개를 만든다', () async {
      final service = FakeTmdbMovieService();
      final viewModel = build(service);

      await viewModel.loadInitial();

      expect(viewModel.movies, hasLength(MovieListViewModel.movieLimit));
      expect(service.discoverCalls.pages, equals([1, 2]));
      expect(viewModel.status, equals(MovieListLoadStatus.success));
    });

    test('페이지 사이에 중복이 있어도 TMDB id 기준으로 하나만 남긴다', () async {
      // 페이지마다 id 가 10개씩만 전진해 이전 페이지와 절반이 겹친다.
      final service = FakeTmdbMovieService(duplicateAcrossPages: true);
      final viewModel = build(service);

      await viewModel.loadInitial();

      final ids = viewModel.movies.ids;
      expect(ids.toSet(), hasLength(ids.length), reason: '중복된 id 가 남아 있다');
      expect(ids, hasLength(MovieListViewModel.movieLimit));
    });

    test('더 이상 페이지가 없으면 30개보다 적어도 오류로 보지 않는다', () async {
      // 장르를 지정하면 결과가 3개뿐이고 total_pages 는 1 이다.
      final service = FakeTmdbMovieService(genreResultCount: 3);
      final viewModel = build(service);

      await viewModel.selectGenres(const [878]);

      expect(viewModel.movies, hasLength(3));
      expect(viewModel.status, equals(MovieListLoadStatus.success));
      // 다음 페이지가 없으므로 한 번만 요청한다.
      expect(service.discoverCalls.pages, equals([1]));
    });
  });

  group('장르 필터', () {
    test('장르를 고르면 with_genres 로 page 1 부터 다시 요청한다', () async {
      final service = FakeTmdbMovieService();
      final viewModel = build(service);

      await viewModel.loadInitial();
      service.discoverCalls.clear();

      await viewModel.selectGenres(const [878]);

      // 이어붙이지 않고 page 1 부터 다시 모은다.
      expect(service.discoverCalls.first.page, equals(1));
      expect(service.discoverCalls.genreIds, everyElement(equals([878])));
      expect(viewModel.selectedGenreIds, equals([878]));
    });

    test('"전체" 를 고르면 with_genres 를 보내지 않는다', () async {
      final service = FakeTmdbMovieService();
      final viewModel = build(service);

      await viewModel.selectGenres(const [878]);
      service.discoverCalls.clear();

      await viewModel.selectGenres(const []);

      expect(service.discoverCalls.genreIds, everyElement(isNull));
      expect(viewModel.selectedGenreIds, isEmpty);
    });

    test('여러 장르를 고르면 그대로 Service 에 넘긴다', () async {
      final service = FakeTmdbMovieService();
      final viewModel = build(service);

      await viewModel.selectGenres(const [878, 16]);

      expect(service.discoverCalls.first.genreIds, equals([878, 16]));
    });

    test('요청 중에는 장르를 바꾸지 못한다', () async {
      final service = FakeTmdbMovieService(
        delay: const Duration(milliseconds: 50),
      );
      final viewModel = build(service);

      // await 하지 않고 첫 요청을 띄워 둔 상태에서
      final pending = viewModel.selectGenres(const [878]);
      expect(viewModel.isBusy, isTrue);

      // 두 번째 선택은 무시된다.
      await viewModel.selectGenres(const [16]);
      await pending;

      expect(viewModel.selectedGenreIds, equals([878]));
    });

    test('고른 장르는 기기에 저장되고 다시 열면 복원된다', () async {
      final preference = GenrePreference();
      final first = MovieListViewModel(
        FakeTmdbMovieService(),
        genrePreference: preference,
      );

      await first.selectGenres(const [878, 16]);
      expect(await preference.read(), equals([878, 16]));

      // 앱을 다시 띄웠다고 보고 복원되는지 확인한다.
      final second = MovieListViewModel(
        FakeTmdbMovieService(),
        genrePreference: preference,
      );
      await second.loadInitial();

      expect(second.selectedGenreIds, equals([878, 16]));
    });
  });

  group('상태', () {
    test('결과가 없으면 empty', () async {
      final viewModel = build(FakeTmdbMovieService(mode: FakeTmdbMode.empty));

      await viewModel.loadInitial();

      expect(viewModel.status, equals(MovieListLoadStatus.empty));
      expect(viewModel.movies, isEmpty);
    });

    test('첫 요청이 실패하면 error 와 안내 문구를 남긴다', () async {
      final viewModel = build(FakeTmdbMovieService(mode: FakeTmdbMode.failure));

      await viewModel.loadInitial();

      expect(viewModel.status, equals(MovieListLoadStatus.error));
      expect(viewModel.message, isNotNull);
      // 내부 예외 내용은 노출하지 않는다.
      expect(viewModel.message, isNot(contains('fake network failure')));
    });

    test('401 은 Token 문제임을 알려준다', () async {
      final viewModel = build(
        FakeTmdbMovieService(mode: FakeTmdbMode.unauthorized),
      );

      await viewModel.loadInitial();

      expect(viewModel.status, equals(MovieListLoadStatus.error));
      expect(viewModel.message, contains('Token'));
    });

    test('이미 목록이 있으면 실패해도 비우지 않고 재시도 안내만 띄운다', () async {
      final service = FakeTmdbMovieService();
      final viewModel = build(service);

      await viewModel.loadInitial();
      final loaded = viewModel.movies;
      expect(loaded, isNotEmpty);

      service.mode = FakeTmdbMode.failure;
      await viewModel.refresh();

      expect(viewModel.movies, same(loaded), reason: '목록이 비워졌다');
      expect(viewModel.status, equals(MovieListLoadStatus.success));
      expect(viewModel.pendingFailureMessage, isNotNull);
    });

    test('재시도가 성공하면 최신 목록으로 교체되고 안내가 사라진다', () async {
      final service = FakeTmdbMovieService();
      final viewModel = build(service);

      await viewModel.loadInitial();
      service.mode = FakeTmdbMode.failure;
      await viewModel.refresh();
      expect(viewModel.pendingFailureMessage, isNotNull);

      service.mode = FakeTmdbMode.success;
      await viewModel.retry();

      expect(viewModel.pendingFailureMessage, isNull);
      expect(viewModel.status, equals(MovieListLoadStatus.success));
    });

    test('새로고침 중에도 기존 목록을 유지한다', () async {
      final service = FakeTmdbMovieService(
        delay: const Duration(milliseconds: 50),
      );
      final viewModel = build(service);

      await viewModel.loadInitial();
      expect(viewModel.movies, isNotEmpty);

      final pending = viewModel.refresh();
      expect(viewModel.isRefreshing, isTrue);
      // Loading 화면으로 바뀌지 않는다.
      expect(viewModel.status, equals(MovieListLoadStatus.success));
      expect(viewModel.movies, isNotEmpty);

      await pending;
    });
  });
}

// MyRatingsViewModel(내가 등록한 평점) 테스트

import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/view_models/session_rating_store.dart';

import 'fakes/fake_auth.dart';
import 'fakes/fake_rating_api_service.dart';
import 'fakes/fake_tmdb_movie_service.dart';
import 'fakes/movie_log_fixtures.dart';
import 'test_helpers.dart';

MyRatingsViewModel buildViewModel({
  FakeRatingApiService? ratingService,
  FakeTmdbMovieService? movieService,
  SessionRatingStore? store,
  int? memberId = testMemberId,
}) {
  return MyRatingsViewModel(
    ratingService ?? FakeRatingApiService(),
    movieService ?? FakeTmdbMovieService(),
    AuthViewModel(
      FakeAuthApiService(),
      FakeMemberApiService(),
      FakeTokenStorage(),
    ),
    store ?? SessionRatingStore(),
    memberId: memberId,
  );
}

void main() {
  test('memberId 를 알면 공개 조회로 전체 목록을 읽는다', () async {
    final service = FakeRatingApiService();
    final viewModel = buildViewModel(ratingService: service);
    await viewModel.load();

    // 6주차의 고정 상수 1 이 아니라 가입 결과로 받은 id 로 묻는다.
    expect(service.fetchCalls, equals([testMemberId]));
    expect(viewModel.source, MyRatingsSource.server);
  });

  group('memberId 를 모를 때 (v7 계약의 한계)', () {
    test('공개 조회를 보내지 않고 이번 세션의 평점만 보여준다', () async {
      final service = FakeRatingApiService();
      final store = SessionRatingStore()..upsert(fakeRating(42, movieId: 550));

      final viewModel = buildViewModel(
        ratingService: service,
        store: store,
        memberId: null,
      );
      await viewModel.load();

      // memberId 를 지어내서 공개 조회를 보내지 않는다.
      expect(service.fetchCalls, isEmpty);
      expect(viewModel.source, MyRatingsSource.session);
      expect(viewModel.ratings.single.rating.ratingId, 42);
    });

    test('세션 평점이 없으면 오류가 아니라 Empty 다', () async {
      final viewModel = buildViewModel(
        store: SessionRatingStore(),
        memberId: null,
      );
      await viewModel.load();

      expect(viewModel.status, MyRatingsLoadStatus.empty);
    });
  });

  group('네 가지 상태', () {
    test('Loading → Success 로 바뀌고 평점을 담는다', () async {
      final viewModel = buildViewModel(
        ratingService: FakeRatingApiService(
          delay: const Duration(milliseconds: 30),
        ),
      );

      final pending = viewModel.load();
      expect(viewModel.status, equals(MyRatingsLoadStatus.loading));

      await pending;
      expect(viewModel.status, equals(MyRatingsLoadStatus.success));
      expect(viewModel.ratings, hasLength(3));
      expect(viewModel.message, isNull);
    });

    test('빈 배열은 실패가 아니라 Empty 다', () async {
      final viewModel = buildViewModel(
        ratingService: FakeRatingApiService(mode: FakeRatingMode.empty),
      );
      await viewModel.load();

      expect(viewModel.status, equals(MyRatingsLoadStatus.empty));
      expect(viewModel.ratings, isEmpty);
      expect(viewModel.message, isNull);
    });

    test('404 는 없는 회원 문구로 Error 가 된다', () async {
      final viewModel = buildViewModel(
        ratingService: FakeRatingApiService(mode: FakeRatingMode.notFound),
      );
      await viewModel.load();

      expect(viewModel.status, equals(MyRatingsLoadStatus.error));
      expect(viewModel.message, equals('존재하지 않는 회원입니다.'));
    });

    test('400 은 memberId 형식 문구로 Error 가 된다', () async {
      final viewModel = buildViewModel(
        ratingService: FakeRatingApiService(mode: FakeRatingMode.badRequest),
      );
      await viewModel.load();

      expect(viewModel.status, equals(MyRatingsLoadStatus.error));
      expect(viewModel.message, equals('memberId 형식을 다시 확인해 주세요.'));
    });

    test('status 없는 통신 실패는 일반 문구로 Error 가 된다', () async {
      final viewModel = buildViewModel(
        ratingService: FakeRatingApiService(mode: FakeRatingMode.failure),
      );
      await viewModel.load();

      expect(viewModel.status, equals(MyRatingsLoadStatus.error));
      expect(viewModel.message, equals('평점을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.'));
    });
  });

  group('TMDB 영화 정보 연결', () {
    test('평점의 movieId 로 영화 정보를 함께 담는다', () async {
      final movieService = FakeTmdbMovieService();
      final viewModel = buildViewModel(movieService: movieService);
      await viewModel.load();

      expect(movieService.movieDetailCalls, equals([550, 680, 13]));
      expect(
        viewModel.ratings.map((entry) => entry.movie?.id).toList(),
        equals([550, 680, 13]),
      );
      expect(viewModel.ratings.first.movie?.title, equals('영화 550'));
    });

    test('같은 movieId 는 한 번만 조회한다', () async {
      final movieService = FakeTmdbMovieService();
      final viewModel = buildViewModel(
        ratingService: FakeRatingApiService(
          ratings: [
            fakeRating(1, movieId: 550),
            fakeRating(2, movieId: 550),
            fakeRating(3, movieId: 680),
          ],
        ),
        movieService: movieService,
      );
      await viewModel.load();

      // 평점은 3건이지만 서로 다른 영화는 2편이다.
      expect(viewModel.ratings, hasLength(3));
      expect(movieService.movieDetailCalls, equals([550, 680]));

      // 다시 불러도 캐시가 있으므로 TMDB 에 더 묻지 않는다.
      await viewModel.load();
      expect(movieService.movieDetailCalls, equals([550, 680]));
    });

    test('TMDB 에 없는 영화(404)여도 평점은 남고 안내만 붙는다', () async {
      final viewModel = buildViewModel(
        movieService: FakeTmdbMovieService(missingMovieIds: const {680}),
      );
      await viewModel.load();

      expect(viewModel.status, equals(MyRatingsLoadStatus.success));
      expect(viewModel.ratings, hasLength(3));

      final missing = viewModel.ratings[1];
      expect(missing.rating.movieId, equals(680));
      expect(missing.movie, isNull);
      expect(viewModel.message, contains('일부 영화 정보를 가져오지 못해'));
    });

    test('TMDB 통신이 모두 실패해도 평점 목록은 비우지 않는다', () async {
      final viewModel = buildViewModel(
        movieService: FakeTmdbMovieService(mode: FakeTmdbMode.failure),
      );
      await viewModel.load();

      // 평점의 주인은 자체 백엔드다. TMDB 실패는 이 화면의 실패가 아니다.
      expect(viewModel.status, equals(MyRatingsLoadStatus.success));
      expect(viewModel.ratings, hasLength(3));
      expect(viewModel.ratings.every((entry) => entry.movie == null), isTrue);
      expect(viewModel.message, contains('일부 영화 정보를 가져오지 못해'));
    });

    test('일시적인 TMDB 실패는 캐시하지 않아 다시 불러올 때 재시도한다', () async {
      final movieService = FakeTmdbMovieService(mode: FakeTmdbMode.failure);
      final viewModel = buildViewModel(movieService: movieService);

      await viewModel.load();
      expect(viewModel.ratings.first.movie, isNull);

      movieService.mode = FakeTmdbMode.success;
      await viewModel.load();

      expect(viewModel.ratings.first.movie?.id, equals(550));
      expect(viewModel.message, isNull);
    });
  });

  test('dispose 뒤에 도착한 응답은 상태를 건드리지 않는다', () async {
    final viewModel = buildViewModel(
      ratingService: FakeRatingApiService(
        delay: const Duration(milliseconds: 50),
      ),
    );

    final pending = viewModel.load();
    viewModel.dispose();

    await expectLater(pending, completes);
    expect(viewModel.status, equals(MyRatingsLoadStatus.loading));
    expect(viewModel.ratings, isEmpty);
  });
}

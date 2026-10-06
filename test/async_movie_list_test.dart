// 비동기 영화 목록의 네 가지 화면 상태 테스트

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/data/mock_movies.dart';
import 'package:movielog/data/preferences/genre_preference.dart';
import 'package:movielog/screens/movies/movie_list_screen.dart';
import 'package:movielog/screens/movies/widgets/movie_grid.dart';
import 'package:movielog/screens/movies/widgets/movie_list_empty.dart';
import 'package:movielog/screens/movies/widgets/movie_list_error.dart';
import 'package:movielog/screens/movies/widgets/movie_list_loading.dart';
import 'package:movielog/services/fake_movie_service.dart';
import 'package:movielog/theme/app_theme.dart';

import 'test_helpers.dart';

void main() {
  setUp(useInMemoryPreferences);

  group('FakeMovieService', () {
    test('success 모드는 Mock 목록을 돌려준다', () async {
      const service = FakeMovieService(delay: Duration.zero);
      expect(await service.fetchMovies(), equals(movies));
    });

    test('empty 모드는 빈 목록을 돌려준다', () async {
      const service = FakeMovieService(
        mode: FakeMovieServiceMode.empty,
        delay: Duration.zero,
      );
      expect(await service.fetchMovies(), isEmpty);
    });

    test('failure 모드는 예외를 던진다', () async {
      const service = FakeMovieService(
        mode: FakeMovieServiceMode.failure,
        delay: Duration.zero,
      );
      expect(service.fetchMovies(), throwsA(isA<Exception>()));
    });

    test('기본 지연은 800ms 이상이다', () {
      expect(
        const FakeMovieService().delay.inMilliseconds,
        greaterThanOrEqualTo(800),
      );
    });
  });

  group('화면 상태', () {
    /// 주어진 모드로 목록 화면을 띄운다.
    Future<void> pumpList(
      WidgetTester tester, {
      FakeMovieServiceMode mode = FakeMovieServiceMode.success,
    }) async {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MovieListScreen(
            service: FakeMovieService(
              mode: mode,
              delay: const Duration(milliseconds: 900),
            ),
          ),
        ),
      );
    }

    testWidgets('Loading — 응답 전에는 스켈레톤을 보여준다', (tester) async {
      await pumpList(tester);

      // 아직 Future 가 끝나지 않은 시점
      expect(find.byType(MovieListLoading), findsOneWidget);
      expect(find.byType(MovieGrid), findsNothing);

      await tester.pump(loadingDelay);
      await tester.pumpAndSettle();
    });

    testWidgets('Success — 응답이 오면 Grid 를 보여준다', (tester) async {
      await pumpList(tester);
      await tester.pump(loadingDelay);
      await tester.pumpAndSettle();

      expect(find.byType(MovieListLoading), findsNothing);
      expect(find.byType(MovieGrid), findsOneWidget);
    });

    testWidgets('Empty — 목록이 비면 안내 문구를 보여준다', (tester) async {
      await pumpList(tester, mode: FakeMovieServiceMode.empty);
      await tester.pump(loadingDelay);
      await tester.pumpAndSettle();

      expect(find.byType(MovieListEmpty), findsOneWidget);
      expect(find.byType(MovieGrid), findsNothing);
    });

    testWidgets('Error — 실패하면 다시 시도 버튼을 보여준다', (tester) async {
      await pumpList(tester, mode: FakeMovieServiceMode.failure);
      await tester.pump(loadingDelay);
      await tester.pumpAndSettle();

      expect(find.byType(MovieListError), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, '다시 시도'), findsOneWidget);

      // 내부 예외 내용이 화면에 노출되지 않아야 한다.
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining('fake network failure'), findsNothing);
    });

    testWidgets('재시도를 누르면 다시 Loading 으로 돌아간다', (tester) async {
      await pumpList(tester, mode: FakeMovieServiceMode.failure);
      await tester.pump(loadingDelay);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, '다시 시도'));
      await tester.pump();

      expect(find.byType(MovieListLoading), findsOneWidget);

      await tester.pump(loadingDelay);
      await tester.pumpAndSettle();
    });
  });

  group('장르 저장', () {
    testWidgets('고른 장르가 저장되고 다시 열면 복원된다', (tester) async {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final preference = GenrePreference();

      // 1회차: SF 를 고른다
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: MovieListScreen(
          service: const FakeMovieService(delay: Duration(milliseconds: 100)),
          genrePreference: preference,
        ),
      ));
      await tester.pump(loadingDelay);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'SF'));
      await tester.pumpAndSettle();

      expect(await preference.read(), equals('SF'));

      // 2회차: 앱을 다시 띄웠다고 보고 복원되는지 확인
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: MovieListScreen(
          key: const ValueKey('second'),
          service: const FakeMovieService(delay: Duration(milliseconds: 100)),
          genrePreference: preference,
        ),
      ));
      await tester.pump(loadingDelay);
      await tester.pumpAndSettle();

      final sfCount = movies.where((m) => m.genres.contains('SF')).length;
      final grid = tester.widget<MovieGrid>(find.byType(MovieGrid));
      expect(grid.movies.length, equals(sfCount));
    });
  });
}

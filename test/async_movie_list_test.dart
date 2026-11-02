// 영화 목록 화면의 네 가지 상태 테스트
//
// 화면은 ViewModel 의 상태를 구독해 그리기만 한다.
// Provider 로 Fake Service 를 끼워 실제 TMDB 요청 없이 확인한다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:movielog/data/preferences/genre_preference.dart';
import 'package:movielog/screens/movies/movie_list_screen.dart';
import 'package:movielog/screens/movies/widgets/movie_grid.dart';
import 'package:movielog/screens/movies/widgets/movie_list_empty.dart';
import 'package:movielog/screens/movies/widgets/movie_list_error.dart';
import 'package:movielog/screens/movies/widgets/movie_list_loading.dart';
import 'package:movielog/screens/movies/widgets/movie_list_retry_dialog.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/view_models/movie_list_view_model.dart';

import 'fakes/fake_tmdb_movie_service.dart';
import 'test_helpers.dart';

void main() {
  setUp(useInMemoryPreferences);

  /// 주어진 Fake 로 목록 화면을 띄운다.
  Future<MovieListViewModel> pumpList(
    WidgetTester tester,
    FakeTmdbMovieService service,
  ) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final viewModel = MovieListViewModel(
      service,
      genrePreference: GenrePreference(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ChangeNotifierProvider<MovieListViewModel>.value(
          value: viewModel,
          child: const MovieListScreen(),
        ),
      ),
    );
    // ignore: discarded_futures  — Loading 상태를 확인하려고 일부러 await 하지 않는다.
    viewModel.loadInitial();
    await tester.pump();

    return viewModel;
  }

  testWidgets('Loading — 응답 전에는 스켈레톤을 보여준다', (tester) async {
    await pumpList(
      tester,
      FakeTmdbMovieService(delay: const Duration(milliseconds: 300)),
    );

    expect(find.byType(MovieListLoading), findsOneWidget);
    expect(find.byType(MovieGrid), findsNothing);

    await tester.pump(loadingDelay);
    await tester.pumpAndSettle();
  });

  testWidgets('Success — 응답이 오면 Grid 를 보여준다', (tester) async {
    await pumpList(tester, FakeTmdbMovieService());
    await tester.pumpAndSettle();

    expect(find.byType(MovieListLoading), findsNothing);
    expect(find.byType(MovieGrid), findsOneWidget);

    final grid = tester.widget<MovieGrid>(find.byType(MovieGrid));
    expect(grid.movies, hasLength(MovieListViewModel.movieLimit));
  });

  testWidgets('Empty — 목록이 비면 안내 문구를 보여준다', (tester) async {
    await pumpList(tester, FakeTmdbMovieService(mode: FakeTmdbMode.empty));
    await tester.pumpAndSettle();

    expect(find.byType(MovieListEmpty), findsOneWidget);
    expect(find.byType(MovieGrid), findsNothing);
  });

  testWidgets('Error — 실패하면 다시 시도 버튼을 보여준다', (tester) async {
    await pumpList(tester, FakeTmdbMovieService(mode: FakeTmdbMode.failure));
    await tester.pumpAndSettle();

    expect(find.byType(MovieListError), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '다시 시도'), findsOneWidget);

    // 내부 예외 내용이 화면에 노출되지 않아야 한다.
    expect(find.textContaining('DioException'), findsNothing);
    expect(find.textContaining('fake network failure'), findsNothing);
  });

  testWidgets('재시도를 누르면 목록을 다시 불러온다', (tester) async {
    final service = FakeTmdbMovieService(mode: FakeTmdbMode.failure);
    await pumpList(tester, service);
    await tester.pumpAndSettle();
    expect(find.byType(MovieListError), findsOneWidget);

    service.mode = FakeTmdbMode.success;
    await tester.tap(find.widgetWithText(ElevatedButton, '다시 시도'));
    await tester.pumpAndSettle();

    expect(find.byType(MovieGrid), findsOneWidget);
  });

  testWidgets('장르 Chip 을 누르면 그 장르로 다시 조회한다', (tester) async {
    final service = FakeTmdbMovieService(genreResultCount: 3);
    await pumpList(tester, service);
    await tester.pumpAndSettle();

    service.discoverCalls.clear();
    await tester.tap(find.widgetWithText(ChoiceChip, 'SF'));
    await tester.pumpAndSettle();

    expect(service.discoverCalls.first.page, equals(1));
    expect(service.discoverCalls.first.genreIds, equals([878]));

    final grid = tester.widget<MovieGrid>(find.byType(MovieGrid));
    expect(grid.movies, hasLength(3));
  });

  testWidgets('"전체" Chip 을 누르면 장르 없이 조회한다', (tester) async {
    final service = FakeTmdbMovieService();
    await pumpList(tester, service);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'SF'));
    await tester.pumpAndSettle();

    service.discoverCalls.clear();
    await tester.tap(find.widgetWithText(ChoiceChip, '전체'));
    await tester.pumpAndSettle();

    expect(service.discoverCalls.genreIds, everyElement(isNull));
  });

  testWidgets('목록이 있는 상태로 실패하면 목록을 지우지 않고 재시도 Dialog 를 띄운다',
      (tester) async {
    final service = FakeTmdbMovieService();
    final viewModel = await pumpList(tester, service);
    await tester.pumpAndSettle();
    expect(find.byType(MovieGrid), findsOneWidget);

    service.mode = FakeTmdbMode.failure;
    await viewModel.refresh();
    await tester.pumpAndSettle();

    expect(find.byType(MovieListRetryDialog), findsOneWidget);
    // 목록은 Dialog 뒤에 그대로 남아 있다.
    expect(find.byType(MovieGrid), findsOneWidget);

    // 취소하면 Dialog 만 닫히고 목록은 유지된다.
    await tester.tap(find.widgetWithText(TextButton, '취소'));
    await tester.pumpAndSettle();

    expect(find.byType(MovieListRetryDialog), findsNothing);
    expect(find.byType(MovieGrid), findsOneWidget);
  });
}

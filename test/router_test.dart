// 화면 전환 테스트

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/router/app_router.dart';
import 'package:movielog/screens/home/home_screen.dart';
import 'package:movielog/screens/movie_detail/movie_detail_screen.dart';
import 'package:movielog/screens/movies/movie_list_screen.dart';
import 'package:movielog/screens/profile/profile_screen.dart';
import 'package:movielog/screens/sign_up/sign_up_screen.dart';
import 'package:movielog/start_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/widgets/movie_card.dart';

import 'fakes/fake_tmdb_movie_service.dart';
import 'test_helpers.dart';

/// Router 를 쓰는 앱을 띄우고 원하는 위치로 이동한다.
///
/// Route 안의 ViewModel 이 공용 Service 를 context.read 로 찾으므로
/// 앱과 같은 모양으로 Provider 를 함께 올린다.
Future<FakeTmdbMovieService> pumpApp(
  WidgetTester tester, {
  String at = '/',
  FakeTmdbMovieService? service,
}) async {
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  final fake = service ?? FakeTmdbMovieService();

  appRouter.go(at);
  await tester.pumpWidget(
    withServices(
      fake,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: appRouter),
    ),
  );
  await tester.pumpAndSettle();

  return fake;
}

void main() {
  setUp(useInMemoryPreferences);
  tearDown(() => appRouter.go('/'));

  testWidgets('시작 → 회원가입 → 홈 흐름에서 뒤로 갈 수 없다', (tester) async {
    await pumpApp(tester);
    expect(find.byType(StartScreen), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, '시작하기'));
    await tester.pumpAndSettle();
    expect(find.byType(SignUpScreen), findsOneWidget);

    // go 로 이동했으므로 돌아갈 스택이 없다.
    expect(appRouter.canPop(), isFalse);

    await tester.enterText(find.byType(TextFormField).at(0), '무비러버');
    await tester.enterText(find.byType(TextFormField).at(1), 'movie@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'password123');
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '가입하기'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(appRouter.canPop(), isFalse);
  });

  testWidgets('NavigationBar 로 세 화면을 전환한다', (tester) async {
    await pumpApp(tester, at: '/home');
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, '영화'));
    await tester.pumpAndSettle();
    expect(find.byType(MovieListScreen), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, '마이'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgets('홈은 인기 영화 5개를 보여준다', (tester) async {
    await pumpApp(tester, at: '/home');

    // 추천 카드 1개 + Grid 4개 = 5개
    expect(find.byType(MovieCard), findsNWidgets(4));
    expect(find.text('영화 1'), findsWidgets);
  });

  testWidgets('영화 카드를 누르면 상세로 가고 뒤로 돌아온다', (tester) async {
    await pumpApp(tester, at: '/movies');

    await tester.tap(find.byType(MovieCard).first);
    await tester.pumpAndSettle();

    expect(find.byType(MovieDetailScreen), findsOneWidget);
    // push 로 이동했으므로 목록으로 돌아갈 수 있다.
    expect(appRouter.canPop(), isTrue);

    appRouter.pop();
    await tester.pumpAndSettle();
    expect(find.byType(MovieListScreen), findsOneWidget);
  });

  testWidgets('상세 경로에는 TMDB 영화 id 가 들어간다', (tester) async {
    await pumpApp(tester, at: '/movies');

    await tester.tap(find.byType(MovieCard).first);
    await tester.pumpAndSettle();

    final detail = tester.widget<MovieDetailScreen>(
      find.byType(MovieDetailScreen),
    );
    // 배열 index(0)가 아니라 TMDB 가 부여한 id 가 전달된다.
    expect(detail.movieId, equals(detail.movie!.id));
    expect(appRouter.state.uri.toString(), equals('/movies/${detail.movieId}'));
  });
}

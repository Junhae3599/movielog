// 화면 전환 테스트

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/router/app_router.dart';
import 'package:movielog/screens/home/home_screen.dart';
import 'package:movielog/screens/movie_detail/movie_detail_loader.dart';
import 'package:movielog/screens/movie_detail/movie_detail_screen.dart';
import 'package:movielog/screens/movies/movie_list_screen.dart';
import 'package:movielog/screens/profile/profile_screen.dart';
import 'package:movielog/screens/sign_up/sign_up_screen.dart';
import 'package:movielog/start_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/widgets/movie_card.dart';
import 'package:movielog/widgets/movie_log_button.dart';

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

  testWidgets('시작 → 회원가입 → 영화 목록 흐름에서 뒤로 갈 수 없다', (tester) async {
    await pumpApp(tester);
    expect(find.byType(StartScreen), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, '시작하기'));
    await tester.pumpAndSettle();
    expect(find.byType(SignUpScreen), findsOneWidget);

    // go 로 이동했으므로 돌아갈 스택이 없다.
    expect(appRouter.canPop(), isFalse);

    await tester.enterText(find.byType(TextFormField).at(0), '무비러버');
    await tester.enterText(find.byType(TextFormField).at(1), 'movie@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'Password123!');
    await tester.pumpAndSettle();

    // 7주차부터는 닉네임·이메일 중복 확인을 모두 통과해야 가입할 수 있다.
    await tester.tap(find.byType(MovieLogButton).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MovieLogButton).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(MovieLogButton).at(2));
    await tester.pumpAndSettle();

    // 가입 성공 뒤에는 영화 목록으로 옮겨 간다.
    expect(find.byType(MovieListScreen), findsOneWidget);
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

    final loader = tester.widget<MovieDetailLoader>(
      find.byType(MovieDetailLoader),
    );
    // 배열 index(0)가 아니라 TMDB 가 부여한 id 가 전달된다.
    expect(loader.movieId, equals(loader.initialMovie!.id));
    expect(appRouter.state.uri.toString(), equals('/movies/${loader.movieId}'));
  });

  testWidgets('URL 로 바로 들어오면 TMDB 상세를 다시 조회한다', (tester) async {
    // 목록을 거치지 않으면 extra 가 없다. Loader 가 경로의 id 로 다시 묻는다.
    final service = await pumpApp(tester, at: '/movies/550');

    expect(service.movieDetailCalls, equals([550]));
    expect(find.byType(MovieDetailScreen), findsOneWidget);
    expect(find.text('영화 550'), findsOneWidget);
  });

  testWidgets('영화 ID 가 숫자가 아니면 안내만 보여준다', (tester) async {
    final service = await pumpApp(tester, at: '/movies/abc');

    expect(find.text('영화 ID가 올바르지 않습니다.'), findsOneWidget);
    // 잘못된 경로로는 TMDB 요청을 보내지 않는다.
    expect(service.movieDetailCalls, isEmpty);
  });
}

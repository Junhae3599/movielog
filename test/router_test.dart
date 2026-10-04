// 화면 전환 테스트

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/data/mock_movies.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/screens/home/home_screen.dart';
import 'package:movielog/screens/movie_detail/movie_detail_screen.dart';
import 'package:movielog/screens/movies/movie_list_screen.dart';
import 'package:movielog/screens/profile/profile_screen.dart';
import 'package:movielog/screens/sign_up/sign_up_screen.dart';
import 'package:movielog/start_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/widgets/movie_card.dart';

/// Router 를 쓰는 앱을 띄우고 원하는 위치로 이동한다.
Future<void> pumpApp(WidgetTester tester, {String at = '/'}) async {
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  appRouter.go(at);
  await tester.pumpWidget(
    MaterialApp.router(theme: AppTheme.light, routerConfig: appRouter),
  );
  await tester.pumpAndSettle();
}

void main() {
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

  testWidgets('Path Parameter 의 ID 로 해당 영화를 보여준다', (tester) async {
    await pumpApp(tester, at: '/movies/3');

    expect(find.text('속삭이는 숲'), findsWidgets);
  });

  testWidgets('장르 Chip 을 누르면 Query Parameter 로 목록을 거른다', (tester) async {
    await pumpApp(tester, at: '/movies');
    expect(find.byType(MovieCard), findsNWidgets(movies.length));

    await tester.tap(find.widgetWithText(ChoiceChip, 'SF'));
    await tester.pumpAndSettle();

    expect(
      appRouter.state.uri.toString(),
      contains('genres=SF'),
    );
    final sf = movies.where((m) => m.genres.contains('SF')).length;
    expect(find.byType(MovieCard), findsNWidgets(sf));
  });
}

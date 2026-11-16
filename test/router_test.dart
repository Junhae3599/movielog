// 화면 전환 테스트
//
// 8주차에 Router 가 인증 상태를 보고 경로를 바꾸므로, 어떤 화면을 테스트하든
// 먼저 "어떤 인증 상태인가" 를 정해야 한다. 그래서 Router 를 상수 대신
// createRouter(authViewModel) 로 만든다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:movielog/router/app_router.dart';
import 'package:movielog/screens/home/home_screen.dart';
import 'package:movielog/screens/login/login_screen.dart';
import 'package:movielog/screens/movie_detail/movie_detail_loader.dart';
import 'package:movielog/screens/movie_detail/movie_detail_screen.dart';
import 'package:movielog/screens/movies/movie_list_screen.dart';
import 'package:movielog/screens/profile/profile_screen.dart';
import 'package:movielog/screens/sign_up/sign_up_screen.dart';
import 'package:movielog/start_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/widgets/movie_card.dart';
import 'package:movielog/widgets/movie_log_button.dart';

import 'fakes/fake_auth.dart';
import 'fakes/fake_tmdb_movie_service.dart';
import 'test_helpers.dart';

/// 테스트 하나가 쓰는 Router. 각 테스트마다 새로 만든다.
late GoRouter router;

/// Router 를 쓰는 앱을 띄우고 원하는 위치로 이동한다.
///
/// [auth] 를 주지 않으면 **이미 로그인한 상태**로 시작한다. 보호 화면을 보는
/// 테스트가 대부분이기 때문이다. 로그아웃 상태를 보려면 직접 넘긴다.
Future<FakeTmdbMovieService> pumpApp(
  WidgetTester tester, {
  String at = '/home',
  FakeTmdbMovieService? service,
  AuthViewModel? auth,
  // 스플래시의 CircularProgressIndicator 는 끝없이 돈다. 그 화면에 머무르는
  // 테스트에서 pumpAndSettle 을 쓰면 영원히 기다린다.
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  final fake = service ?? FakeTmdbMovieService();
  final viewModel = auth ?? await signedInAuthViewModel();

  router = createRouter(viewModel);
  addTearDown(router.dispose);

  router.go(at);
  await tester.pumpWidget(
    withServices(
      fake,
      authViewModel: viewModel,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }

  return fake;
}

void main() {
  setUp(useInMemoryPreferences);

  group('인증 상태별 redirect', () {
    testWidgets('확인 중에는 스플래시를 유지하고 보호 화면으로 가지 않는다', (tester) async {
      // 저장소 읽기를 붙잡아 두어 initializing 상태를 유지한다.
      final auth = AuthViewModel(
        FakeAuthApiService(),
        FakeMemberApiService(),
        FakeTokenStorage(),
      );

      await pumpApp(tester, at: '/home', auth: auth, settle: false);

      expect(find.byType(StartScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      // 확인 중에는 재시도 버튼 대신 인디케이터를 보여준다.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('다시 시도'), findsNothing);
    });

    testWidgets('세션 확인에 실패하면 Token 을 지우지 않고 재시도 화면을 보여준다', (tester) async {
      // Token 은 있지만 서버 확인이 네트워크 오류로 실패한다.
      final storage = FakeTokenStorage(token: 'saved.token');
      final auth = AuthViewModel(
        FakeAuthApiService(),
        FakeMemberApiService(fetchError: networkError()),
        storage,
      );

      await pumpApp(tester, at: '/home', auth: auth, settle: false);
      await auth.restoreSession();
      await tester.pumpAndSettle();

      expect(auth.status, AuthStatus.retryRequired);
      expect(find.text('다시 시도'), findsOneWidget);
      // 네트워크 실패로 유효할 수도 있는 Token 을 지우지 않는다.
      expect(storage.deleteCount, 0);
      expect(storage.token, 'saved.token');
    });

    testWidgets('로그아웃 상태에서 보호 화면으로 가면 로그인 화면으로 보낸다', (tester) async {
      final auth = AuthViewModel(
        FakeAuthApiService(),
        FakeMemberApiService(),
        FakeTokenStorage(),
      );
      await auth.restoreSession(); // Token 없음 → signedOut

      await pumpApp(tester, at: '/my', auth: auth);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(ProfileScreen), findsNothing);
    });

    testWidgets('로그인하면 Router 가 홈으로 보낸다', (tester) async {
      final auth = AuthViewModel(
        FakeAuthApiService(),
        FakeMemberApiService(),
        FakeTokenStorage(),
      );
      await auth.restoreSession();

      await pumpApp(tester, at: '/login', auth: auth);
      expect(find.byType(LoginScreen), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), testMemberEmail);
      await tester.enterText(find.byType(TextFormField).at(1), 'Umc1234!');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MovieLogButton, '로그인'));
      await tester.pumpAndSettle();

      // 화면이 직접 context.go 를 하지 않아도 상태 변화만으로 이동한다.
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('로그인 상태에서 /login 으로 가면 홈으로 되돌린다', (tester) async {
      await pumpApp(tester, at: '/login');

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('로그아웃하면 보호 화면이 사라지고 로그인 화면이 열린다', (tester) async {
      final auth = await signedInAuthViewModel();
      await pumpApp(tester, at: '/my', auth: auth);
      expect(find.byType(ProfileScreen), findsOneWidget);

      await auth.logout();
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(ProfileScreen), findsNothing);
    });
  });

  group('authRedirect 규칙', () {
    test('공개 화면은 로그아웃 상태에서도 막지 않는다', () {
      expect(authRedirect(AuthStatus.signedOut, '/login'), isNull);
      expect(authRedirect(AuthStatus.signedOut, '/sign-up'), isNull);
      expect(authRedirect(AuthStatus.signedOut, '/home'), '/login');
    });

    test('확인 중에는 어디로 가려 해도 스플래시로 돌린다', () {
      expect(authRedirect(AuthStatus.initializing, '/'), isNull);
      expect(authRedirect(AuthStatus.initializing, '/home'), '/');
      expect(authRedirect(AuthStatus.initializing, '/login'), '/');
    });

    test('로그인 상태에서는 보호 화면을 그대로 둔다', () {
      expect(authRedirect(AuthStatus.signedIn, '/my/ratings'), isNull);
      expect(authRedirect(AuthStatus.signedIn, '/'), '/home');
    });
  });

  testWidgets('로그인 화면에서 회원가입으로 갔다가 돌아올 수 있다', (tester) async {
    final auth = AuthViewModel(
      FakeAuthApiService(),
      FakeMemberApiService(),
      FakeTokenStorage(),
    );
    await auth.restoreSession();

    await pumpApp(tester, at: '/login', auth: auth);

    // push 로 열리므로 가입을 그만두고 로그인으로 돌아갈 수 있다.
    await tester.tap(find.widgetWithText(TextButton, '회원가입'));
    await tester.pumpAndSettle();
    expect(find.byType(SignUpScreen), findsOneWidget);
    expect(router.canPop(), isTrue);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
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
    expect(router.canPop(), isTrue);

    router.pop();
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
    expect(router.state.uri.toString(), equals('/movies/${loader.movieId}'));
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

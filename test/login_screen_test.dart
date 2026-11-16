// 로그인 화면 테스트 (8주차)
//
// 화면이 지켜야 하는 것은 셋이다.
//   1. 통신 중에는 입력과 버튼을 잠근다.
//   2. 로그인 실패 문구와 세션 만료 안내를 섞지 않는다.
//   3. 저장하는 것은 이메일뿐이다. 비밀번호와 Token 은 저장하지 않는다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movielog/screens/login/login_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/widgets/movie_log_button.dart';

import 'fakes/fake_auth.dart';
import 'test_helpers.dart';

const _savedEmailKey = 'movielog.saved_email';

Future<AuthViewModel> pumpLogin(
  WidgetTester tester, {
  FakeAuthApiService? authApi,
  FakeTokenStorage? storage,
  AuthViewModel? auth,
}) async {
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  final viewModel = auth ??
      AuthViewModel(
        authApi ?? FakeAuthApiService(),
        FakeMemberApiService(),
        storage ?? FakeTokenStorage(),
      );
  // 로그인 화면은 signedOut 에서 열린다.
  if (auth == null) await viewModel.restoreSession();

  await tester.pumpWidget(
    ChangeNotifierProvider<AuthViewModel>.value(
      value: viewModel,
      child: MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
    ),
  );
  await tester.pumpAndSettle();

  return viewModel;
}

Future<void> fillAndSubmit(
  WidgetTester tester, {
  String email = 'movie@example.com',
  String password = 'Umc1234!',
}) async {
  await tester.enterText(find.byType(TextFormField).at(0), email);
  await tester.enterText(find.byType(TextFormField).at(1), password);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(MovieLogButton, '로그인'));
}

void main() {
  setUp(useInMemoryPreferences);

  testWidgets('빈 칸으로 누르면 요청을 보내지 않는다', (tester) async {
    final authApi = FakeAuthApiService();
    await pumpLogin(tester, authApi: authApi);

    await tester.tap(find.widgetWithText(MovieLogButton, '로그인'));
    await tester.pumpAndSettle();

    expect(find.text('이메일을 입력해 주세요.'), findsOneWidget);
    expect(find.text('비밀번호를 입력해 주세요.'), findsOneWidget);
    expect(authApi.calls, isEmpty);
  });

  testWidgets('통신 중에는 입력과 버튼이 잠긴다', (tester) async {
    final authApi = FakeAuthApiService(
      delay: const Duration(milliseconds: 60),
    );
    await pumpLogin(tester, authApi: authApi);

    await fillAndSubmit(tester);
    await tester.pump();

    final button = tester.widget<MovieLogButton>(find.byType(MovieLogButton));
    expect(button.isLoading, isTrue);
    // 보낸 값과 화면의 값이 달라지지 않도록 입력도 함께 잠근다.
    final fields = tester.widgetList<TextFormField>(find.byType(TextFormField));
    expect(fields.every((field) => field.enabled == false), isTrue);

    await tester.pumpAndSettle();
  });

  testWidgets('로그인 실패는 화면에 남고 만료 Snackbar 는 뜨지 않는다', (tester) async {
    await pumpLogin(
      tester,
      authApi: FakeAuthApiService(error: authError('AUTH401_1')),
    );

    await fillAndSubmit(tester, password: 'wrong');
    await tester.pumpAndSettle();

    expect(find.text('이메일 또는 비밀번호를 확인해 주세요.'), findsOneWidget);
    // 입력 오류를 만료로 안내하면 사용자가 엉뚱한 설명을 읽는다.
    expect(find.text('로그인이 만료됐어요. 다시 로그인해 주세요.'), findsNothing);
  });

  testWidgets('만료로 열리면 Snackbar 가 한 번만 뜬다', (tester) async {
    final auth = await signedInAuthViewModel();
    await auth.expireSession();

    await pumpLogin(tester, auth: auth);

    expect(find.text('로그인이 만료됐어요. 다시 로그인해 주세요.'), findsOneWidget);
    // 표시를 소비했으므로 다시 그려도 반복되지 않는다.
    expect(auth.sessionExpired, isFalse);
  });

  testWidgets('직접 로그아웃했을 때는 만료 Snackbar 가 뜨지 않는다', (tester) async {
    final auth = await signedInAuthViewModel();
    await auth.logout();

    await pumpLogin(tester, auth: auth);

    expect(find.text('로그인이 만료됐어요. 다시 로그인해 주세요.'), findsNothing);
  });

  group('이메일 저장 (Challenge)', () {
    testWidgets('체크하면 이메일만 저장하고 비밀번호는 저장하지 않는다', (tester) async {
      await pumpLogin(tester);

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await fillAndSubmit(tester);
      await tester.pumpAndSettle();

      final preferences = SharedPreferencesAsync();
      expect(await preferences.getString(_savedEmailKey), 'movie@example.com');

      // 저장된 key 중 어디에도 비밀번호가 없어야 한다.
      final all = await preferences.getAll();
      expect(
        all.values.any((value) => '$value'.contains('Umc1234!')),
        isFalse,
      );
    });

    testWidgets('저장된 이메일은 다음 로그인 화면에 채워진다', (tester) async {
      useInMemoryPreferences(
        initial: {_savedEmailKey: 'saved@example.com'},
      );
      await pumpLogin(tester);
      await tester.pumpAndSettle();

      expect(find.text('saved@example.com'), findsOneWidget);
      final checkbox = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(checkbox.value, isTrue);
    });

    testWidgets('체크를 풀면 저장된 이메일을 지운다', (tester) async {
      useInMemoryPreferences(
        initial: {_savedEmailKey: 'saved@example.com'},
      );
      await pumpLogin(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await fillAndSubmit(tester);
      await tester.pumpAndSettle();

      expect(await SharedPreferencesAsync().getString(_savedEmailKey), isNull);
    });
  });
}

// MovieLog 화면 스모크 테스트

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:movielog/screens/profile/profile_screen.dart';
import 'package:movielog/screens/profile/widgets/profile_header.dart';
import 'package:movielog/start_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/widgets/movie_log_button.dart';

import 'fakes/fake_auth.dart';
import 'fakes/movie_log_fixtures.dart';
import 'test_helpers.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

/// 마이페이지는 AuthViewModel.member 를 구독하므로 함께 올린다.
Widget _wrapProfile(AuthViewModel auth) {
  return ChangeNotifierProvider<AuthViewModel>.value(
    value: auth,
    child: _wrap(const ProfileScreen()),
  );
}

void main() {
  group('프로필 화면', () {
    testWidgets('서버에서 받은 내 정보를 보여준다', (tester) async {
      // 1주차의 하드코딩된 '무비러버' 가 아니라 GET me 응답에서 온 값이다.
      final auth = await signedInAuthViewModel(
        memberApi: FakeMemberApiService(
          member: fakeMemberInfo(nickname: '영화광', email: 'me@movielog.com'),
        ),
      );
      await tester.pumpWidget(_wrapProfile(auth));
      await tester.pumpAndSettle();

      expect(find.text('내 프로필'), findsOneWidget);
      expect(find.text('영화광'), findsOneWidget);
      expect(find.text('me@movielog.com'), findsOneWidget);
      // Challenge: 가입일을 "2026.10.10 가입" 형식으로 보여준다.
      expect(find.textContaining('가입'), findsOneWidget);
      expect(find.widgetWithText(TextButton, '프로필 수정'), findsOneWidget);
      expect(find.widgetWithText(TextButton, '로그아웃'), findsOneWidget);
    });

    testWidgets('내 정보를 못 받았으면 재시도 버튼을 보여준다', (tester) async {
      final auth = await signedInAuthViewModel(
        memberApi: FakeMemberApiService(fetchError: networkError()),
      );
      await tester.pumpWidget(_wrapProfile(auth));
      await tester.pumpAndSettle();

      // 네트워크 실패이므로 로그아웃시키지 않고 재시도만 제공한다.
      expect(auth.status, AuthStatus.signedIn);
      expect(find.widgetWithText(MovieLogButton, '다시 시도'), findsOneWidget);
    });

    testWidgets('이미지가 없으면 기본 아이콘을 보여준다', (tester) async {
      await tester.pumpWidget(
        _wrap(const Scaffold(
          body: ProfileHeader(nickname: '무비러버', introduction: '소개'),
        )),
      );

      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });
  });

  group('시작 화면', () {
    testWidgets('세션 확인 중에는 인디케이터만 보여준다', (tester) async {
      await tester.pumpWidget(_wrap(const StartScreen()));
      await tester.pump();

      // 1주차 레이아웃을 그대로 쓰되, '시작하기' 버튼 자리가 바뀌었다.
      expect(find.text('영화의 순간을\n기록하세요'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('다시 시도'), findsNothing);
    });

    testWidgets('세션 확인에 실패하면 안내와 재시도 버튼을 보여준다', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        _wrap(StartScreen(message: '확인하지 못했어요.', onRetry: () => retried++)),
      );
      await tester.pumpAndSettle();

      expect(find.text('확인하지 못했어요.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(find.widgetWithText(MovieLogButton, '다시 시도'));
      expect(retried, 1);
    });
  });

  group('회원가입 화면', () {
    /// 가입하기 버튼 위젯을 찾는다.
    ElevatedButton submitButton(WidgetTester tester) =>
        tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, '가입하기'),
        );

    testWidgets('입력 전에는 가입 버튼이 비활성화된다', (tester) async {
      await tester.pumpWidget(_wrap(signUpScreen()));

      expect(find.text('닉네임'), findsOneWidget);
      expect(find.text('이메일'), findsOneWidget);
      expect(find.text('비밀번호'), findsOneWidget);
      expect(submitButton(tester).onPressed, isNull);
    });

    testWidgets('잘못된 입력에는 한국어 오류 메시지가 표시된다', (tester) async {
      await tester.pumpWidget(_wrap(signUpScreen()));

      await tester.enterText(find.byType(TextFormField).at(0), 'a');
      await tester.enterText(find.byType(TextFormField).at(1), 'test@');
      await tester.enterText(find.byType(TextFormField).at(2), '123');
      await tester.pumpAndSettle();

      expect(find.text('닉네임은 2자 이상이어야 합니다.'), findsOneWidget);
      expect(find.text('올바른 이메일 형식이 아닙니다.'), findsOneWidget);
      expect(find.text('비밀번호는 8자 이상이어야 합니다.'), findsOneWidget);
      expect(submitButton(tester).onPressed, isNull);
    });

    testWidgets('중복 확인과 약관까지 모두 통과해야 가입 버튼이 활성화된다', (tester) async {
      await tester.pumpWidget(_wrap(signUpScreen()));

      await tester.enterText(find.byType(TextFormField).at(0), '무비러버');
      await tester.enterText(find.byType(TextFormField).at(1), 'movie@example.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'Password123!');
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // 형식과 약관을 통과했어도 중복 확인을 하지 않았으면 켜지지 않는다.
      expect(submitButton(tester).onPressed, isNull);

      // 등장 순서: 닉네임 확인 / 이메일 확인 / 가입하기
      await tester.tap(find.byType(MovieLogButton).at(0));
      await tester.pumpAndSettle();
      // 한쪽만 확인해도 아직 켜지지 않는다.
      expect(submitButton(tester).onPressed, isNull);

      await tester.tap(find.byType(MovieLogButton).at(1));
      await tester.pumpAndSettle();

      expect(submitButton(tester).onPressed, isNotNull);
    });

    testWidgets('비밀번호 문자 조합이 모자라면 오류를 보여준다', (tester) async {
      await tester.pumpWidget(_wrap(signUpScreen()));

      // 8자를 넘겼지만 소문자뿐이다. 서버 제약과 같은 규칙으로 미리 막는다.
      await tester.enterText(find.byType(TextFormField).at(2), 'onlylower');
      await tester.pumpAndSettle();

      expect(
        find.textContaining('소문자·대문자·숫자·특수문자'),
        findsOneWidget,
      );
      expect(submitButton(tester).onPressed, isNull);
    });

    testWidgets('비밀번호 표시 버튼으로 가림 상태가 바뀐다', (tester) async {
      await tester.pumpWidget(_wrap(signUpScreen()));

      expect(find.byIcon(Icons.visibility_off), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });
  });

  group('회원가입 레이아웃', () {
    /// 주어진 크기와 텍스트 배율로 회원가입 화면을 띄운다.
    Future<void> pumpAt(WidgetTester tester, Size size,
        {double scale = 1.0}) async {
      tester.view.physicalSize = size * 2.0;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(scale),
        ),
        child: MaterialApp(theme: AppTheme.light, home: signUpScreen()),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('넓은 화면에서는 AppBar 대신 제목을 보여준다', (tester) async {
      await pumpAt(tester, const Size(1280, 900));

      expect(find.byType(AppBar), findsNothing);
      expect(find.text('MovieLog에 오신 것을 환영합니다!'), findsOneWidget);
    });

    testWidgets('좁은 화면에서는 AppBar 를 보여준다', (tester) async {
      await pumpAt(tester, const Size(390, 845));

      expect(find.byType(AppBar), findsOneWidget);
    });

    // 글꼴에 따라 실제 높이가 커져도 Overflow 없이 푸터까지 보여야 한다.
    // IntrinsicHeight 를 넓은 화면까지 쓰면 여기서 깨진다.
    testWidgets('화면 크기와 글자 배율이 달라져도 Overflow 가 없다', (tester) async {
      for (final size in [
        const Size(1860, 700),
        const Size(1860, 560),
        const Size(390, 845),
      ]) {
        for (final scale in [1.0, 1.3]) {
          await pumpAt(tester, size, scale: scale);

          expect(tester.takeException(), isNull,
              reason: '$size scale=$scale 에서 Overflow');
          expect(find.text('이미 계정이 있나요?'), findsOneWidget,
              reason: '$size scale=$scale 에서 푸터가 잘림');
        }
      }
    });
  });
}

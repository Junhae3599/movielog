// 회원가입 화면의 중복 확인 테스트
//
// 확인 전 / 통신 중 / 사용 가능 / 중복 네 가지가 화면에서 구분되는지,
// 입력을 바꾸면 이전 결과가 사라지는지 확인한다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/widgets/movie_log_button.dart';

import 'fakes/fake_sign_up_service.dart';
import 'test_helpers.dart';

// 화면의 MovieLogButton 은 등장 순서대로 닉네임 확인 / 이메일 확인 / 가입하기다.
//
// 글자로 찾지 않는 이유: 통신 중에는 label Text 대신 인디케이터만 그리므로
// `widgetWithText` 로는 그 버튼을 더 찾을 수 없다.
// (Finder 는 평가 결과를 캐시하므로 final 변수가 아니라 getter 로 둔다)
Finder get nicknameCheckButton => find.byType(MovieLogButton).at(0);
Finder get emailCheckButton => find.byType(MovieLogButton).at(1);
Finder get submitButton => find.byType(MovieLogButton).at(2);

Future<FakeSignUpService> pumpSignUp(
  WidgetTester tester, {
  FakeSignUpService? service,
}) async {
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  final fake = service ?? FakeSignUpService();
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.light, home: signUpScreen(service: fake)),
  );
  await tester.pumpAndSettle();

  return fake;
}

/// 닉네임을 입력하고 중복 확인 버튼을 누른다.
Future<void> checkNickname(WidgetTester tester, String nickname) async {
  await tester.enterText(find.byType(TextFormField).at(0), nickname);
  await tester.pumpAndSettle();
  await tester.tap(nicknameCheckButton);
}

MovieLogButton buttonOf(WidgetTester tester, Finder finder) =>
    tester.widget<MovieLogButton>(finder);

void main() {
  testWidgets('확인 전 — 버튼이 눌리는 상태이고 안내 문구가 없다', (tester) async {
    await pumpSignUp(tester);

    expect(find.text('중복 확인'), findsNWidgets(2));
    expect(buttonOf(tester, nicknameCheckButton).isLoading, isFalse);
    expect(find.text('사용할 수 있는 닉네임입니다.'), findsNothing);
    expect(find.text('이미 사용 중인 닉네임입니다.'), findsNothing);
  });

  testWidgets('통신 중 — 버튼이 비활성화되고 인디케이터만 보인다', (tester) async {
    await pumpSignUp(
      tester,
      service: FakeSignUpService(delay: loadingDelay),
    );

    await checkNickname(tester, '무비러버');
    await tester.pump();

    final button = buttonOf(tester, nicknameCheckButton);
    expect(button.isLoading, isTrue);
    // 통신 중에는 글자 대신 인디케이터만 그린다.
    expect(
      find.descendant(
        of: nicknameCheckButton,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    final elevated = tester.widget<ElevatedButton>(
      find.descendant(
        of: nicknameCheckButton,
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(elevated.onPressed, isNull);

    await tester.pumpAndSettle(loadingDelay);
  });

  testWidgets('사용 가능 — 안내 문구가 뜨고 에러가 아니다', (tester) async {
    await pumpSignUp(tester);

    await checkNickname(tester, '무비러버');
    await tester.pumpAndSettle();

    expect(find.text('사용할 수 있는 닉네임입니다.'), findsOneWidget);
    expect(find.text('이미 사용 중인 닉네임입니다.'), findsNothing);
  });

  testWidgets('중복 — 입력창이 에러 상태가 되고 버튼이 비활성화된다', (tester) async {
    await pumpSignUp(
      tester,
      service: FakeSignUpService(nicknameMode: FakeCheckMode.duplicated),
    );

    await checkNickname(tester, '무비러버');
    await tester.pumpAndSettle();

    // 형식은 통과했지만 서버 결과로 Form 이 에러 상태가 된다.
    expect(find.text('이미 사용 중인 닉네임입니다.'), findsOneWidget);
    expect(find.text('사용할 수 있는 닉네임입니다.'), findsNothing);

    final elevated = tester.widget<ElevatedButton>(
      find.descendant(
        of: nicknameCheckButton,
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(elevated.onPressed, isNull);
  });

  testWidgets('통신 실패 — 중복과 다른 문구를 보여준다', (tester) async {
    await pumpSignUp(
      tester,
      service: FakeSignUpService(nicknameMode: FakeCheckMode.failure),
    );

    await checkNickname(tester, '무비러버');
    await tester.pumpAndSettle();

    expect(find.text('중복 확인에 실패했어요. 다시 시도해 주세요.'), findsOneWidget);
    expect(find.text('이미 사용 중인 닉네임입니다.'), findsNothing);
  });

  testWidgets('입력을 바꾸면 이전 확인 결과가 사라진다', (tester) async {
    await pumpSignUp(tester);

    await checkNickname(tester, '무비러버');
    await tester.pumpAndSettle();
    expect(find.text('사용할 수 있는 닉네임입니다.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), '무비러버2');
    await tester.pumpAndSettle();

    expect(find.text('사용할 수 있는 닉네임입니다.'), findsNothing);
  });

  testWidgets('중복이었던 값을 다시 입력하면 재요청 없이 바로 에러가 된다', (tester) async {
    final service = await pumpSignUp(
      tester,
      service: FakeSignUpService(nicknameMode: FakeCheckMode.duplicated),
    );

    await checkNickname(tester, '무비러버');
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '무비');
    await tester.pumpAndSettle();
    expect(find.text('이미 사용 중인 닉네임입니다.'), findsNothing);

    await tester.enterText(find.byType(TextFormField).at(0), '무비러버');
    await tester.pumpAndSettle();

    expect(find.text('이미 사용 중인 닉네임입니다.'), findsOneWidget);
    // 서버에는 한 번만 물었다.
    expect(service.nicknameCalls, equals(['무비러버']));
  });

  testWidgets('닉네임 결과가 이메일 입력란에 영향을 주지 않는다', (tester) async {
    await pumpSignUp(
      tester,
      service: FakeSignUpService(
        nicknameMode: FakeCheckMode.duplicated,
        emailMode: FakeCheckMode.available,
      ),
    );

    await checkNickname(tester, '무비러버');
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(1),
      'movie@example.com',
    );
    await tester.pumpAndSettle();
    await tester.tap(emailCheckButton);
    await tester.pumpAndSettle();

    expect(find.text('이미 사용 중인 닉네임입니다.'), findsOneWidget);
    expect(find.text('사용할 수 있는 이메일입니다.'), findsOneWidget);
    expect(find.text('이미 사용 중인 이메일입니다.'), findsNothing);
  });

  testWidgets('중복인 값으로는 가입 버튼이 켜지지 않는다', (tester) async {
    await pumpSignUp(
      tester,
      service: FakeSignUpService(nicknameMode: FakeCheckMode.duplicated),
    );

    await checkNickname(tester, '무비러버');
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(1),
      'movie@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'Password123!');
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    final submit = tester.widget<ElevatedButton>(
      find.descendant(of: submitButton, matching: find.byType(ElevatedButton)),
    );
    expect(submit.onPressed, isNull);
  });

  group('MovieLogButton 의 너비', () {
    testWidgets('입력창 옆 버튼은 내용 기반, Form 아래 버튼은 최대 너비다', (tester) async {
      await pumpSignUp(tester);

      final check = buttonOf(tester, nicknameCheckButton);
      final submit = buttonOf(tester, submitButton);

      expect(check.width, isNull);
      expect(submit.width, equals(double.infinity));

      // 실제 그려진 너비도 다르다. 제출 버튼이 Form 전체 너비를 차지한다.
      final checkWidth = tester.getSize(nicknameCheckButton).width;
      final submitWidth = tester.getSize(submitButton).width;
      expect(checkWidth, lessThan(submitWidth));

      // 입력창 옆 버튼은 입력창과 같은 높이를 쓴다.
      expect(
        tester.getSize(nicknameCheckButton).height,
        equals(tester.getSize(find.byType(TextFormField).at(0)).height),
      );
    });
  });
}

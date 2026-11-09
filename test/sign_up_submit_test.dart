// 회원가입 POST 테스트
//
// 성공 result 의 memberId 를 어떻게 다루는지, 실패를 **어디에** 보여주는지
// (비밀번호 입력칸 vs 화면 Snackbar)를 확인한다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/view_models/learning_member_session.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';
import 'package:movielog/view_models/submit_status.dart';
import 'package:movielog/widgets/movie_log_button.dart';

import 'fakes/fake_sign_up_service.dart';
import 'test_helpers.dart';

const _request = CreateMemberRequest(
  email: 'movie@example.com',
  password: 'Password123!',
  nickname: '무비러버',
);

/// 화면의 MovieLogButton 은 등장 순서대로 닉네임 확인 / 이메일 확인 / 가입하기다.
Finder get submitButton => find.byType(MovieLogButton).at(2);

/// 중복 확인까지 끝내고 가입 버튼을 누를 수 있는 상태로 Form 을 채운다.
Future<void> fillValidForm(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), '무비러버');
  await tester.enterText(find.byType(TextFormField).at(1), 'movie@example.com');
  await tester.enterText(find.byType(TextFormField).at(2), 'Password123!');
  await tester.tap(find.byType(Checkbox));
  await tester.pumpAndSettle();

  await tester.tap(find.byType(MovieLogButton).at(0));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(MovieLogButton).at(1));
  await tester.pumpAndSettle();
}

/// 회원가입 화면을 띄운다.
///
/// 가입에 성공하면 화면이 `context.go('/movies')` 를 부르므로 GoRouter 가 필요하다.
/// 이동한 곳이 어디인지만 확인하면 되니 목적지는 간단한 화면으로 둔다.
Future<LearningMemberSession> pumpSignUp(
  WidgetTester tester, {
  required FakeSignUpService service,
}) async {
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  final session = LearningMemberSession();
  final router = GoRouter(
    initialLocation: '/sign-up',
    routes: [
      GoRoute(
        path: '/sign-up',
        builder: (context, state) =>
            signUpScreen(service: service, session: session),
      ),
      GoRoute(
        path: '/movies',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('영화 목록'))),
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
  await tester.pumpAndSettle();

  return session;
}

void main() {
  group('SignUpViewModel.submit', () {
    test('성공하면 result 의 memberId 를 담는다', () async {
      final viewModel = SignUpViewModel(
        FakeSignUpService(createdMemberId: 42),
      );
      await viewModel.submit(_request);

      expect(viewModel.submitStatus, equals(SubmitStatus.success));
      expect(viewModel.createdMemberId, equals(42));
      expect(viewModel.passwordErrorText, isNull);
      expect(viewModel.snackbarMessage, isNull);
    });

    test('비밀번호를 가리키는 400 은 비밀번호 입력칸으로 보낸다', () async {
      final viewModel = SignUpViewModel(
        FakeSignUpService(signUpMode: FakeSignUpMode.invalidPassword),
      );
      await viewModel.submit(_request);

      expect(viewModel.submitStatus, equals(SubmitStatus.error));
      // 서버 문구를 그대로 쓴다. code 별 문구를 새로 만들지 않는다.
      expect(viewModel.passwordErrorText, contains('비밀번호'));
      expect(viewModel.snackbarMessage, isNull);
      expect(viewModel.createdMemberId, isNull);
    });

    test('비밀번호가 아닌 400 은 Snackbar 로 보낸다', () async {
      final viewModel = SignUpViewModel(
        FakeSignUpService(signUpMode: FakeSignUpMode.invalidOther),
      );
      await viewModel.submit(_request);

      expect(viewModel.passwordErrorText, isNull);
      expect(viewModel.snackbarMessage, equals('입력값이 올바르지 않습니다.'));
    });

    test('409 는 최종 중복 결과이므로 Snackbar 로 보낸다', () async {
      final viewModel = SignUpViewModel(
        FakeSignUpService(signUpMode: FakeSignUpMode.duplicated),
      );
      await viewModel.submit(_request);

      expect(viewModel.submitStatus, equals(SubmitStatus.error));
      expect(viewModel.snackbarMessage, equals('이미 사용 중인 이메일입니다.'));
      expect(viewModel.passwordErrorText, isNull);
    });

    test('result 가 없으면 가입 완료로 보지 않는다', () async {
      final viewModel = SignUpViewModel(
        FakeSignUpService(signUpMode: FakeSignUpMode.missingResult),
      );
      await viewModel.submit(_request);

      expect(viewModel.submitStatus, equals(SubmitStatus.error));
      expect(viewModel.createdMemberId, isNull);
      expect(viewModel.snackbarMessage, contains('가입 결과를 확인하지 못했습니다'));
    });

    test('통신 실패는 기본 문구로 안내한다', () async {
      final viewModel = SignUpViewModel(
        FakeSignUpService(signUpMode: FakeSignUpMode.failure),
      );
      await viewModel.submit(_request);

      expect(viewModel.snackbarMessage, contains('회원가입에 실패했습니다'));
    });

    test('제출 중에는 같은 요청을 다시 보내지 않는다', () async {
      final service = FakeSignUpService(
        delay: const Duration(milliseconds: 30),
      );
      final viewModel = SignUpViewModel(service);

      final first = viewModel.submit(_request);
      expect(viewModel.isSubmitting, isTrue);

      await viewModel.submit(_request); // 무시된다
      await first;

      expect(service.signUpCalls, hasLength(1));
    });

    test('비밀번호를 고치면 서버가 준 400 문구가 사라진다', () async {
      final viewModel = SignUpViewModel(
        FakeSignUpService(signUpMode: FakeSignUpMode.invalidPassword),
      );
      await viewModel.submit(_request);
      expect(viewModel.passwordErrorText, isNotNull);

      viewModel.onPasswordChanged();
      expect(viewModel.passwordErrorText, isNull);
    });

    test('닉네임을 바꾸면 이전 가입 실패 문구가 무효화된다', () async {
      final viewModel = SignUpViewModel(
        FakeSignUpService(signUpMode: FakeSignUpMode.duplicated),
      );
      await viewModel.submit(_request);
      expect(viewModel.snackbarMessage, isNotNull);

      viewModel.onNicknameChanged('다른닉네임');

      expect(viewModel.snackbarMessage, isNull);
      expect(viewModel.submitStatus, equals(SubmitStatus.idle));
    });

    test('Snackbar 문구는 한 번만 꺼낸다', () async {
      final viewModel = SignUpViewModel(
        FakeSignUpService(signUpMode: FakeSignUpMode.duplicated),
      );
      await viewModel.submit(_request);

      expect(viewModel.consumeSnackbarMessage(), isNotNull);
      expect(viewModel.consumeSnackbarMessage(), isNull);
    });
  });

  group('회원가입 화면', () {
    testWidgets('성공하면 memberId 를 학습용 세션에 담는다', (tester) async {
      final service = FakeSignUpService(createdMemberId: 55);
      final session = await pumpSignUp(tester, service: service);

      await fillValidForm(tester);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(session.memberId, equals(55));
      // 가입 뒤에는 영화 목록으로 옮겨 간다.
      expect(find.text('영화 목록'), findsOneWidget);
      // 보낸 body 에는 세 값이 모두 들어간다. (비밀번호는 출력하지 않는다)
      expect(service.signUpCalls.single['email'], equals('movie@example.com'));
      expect(service.signUpCalls.single['nickname'], equals('무비러버'));
      expect(service.signUpCalls.single.containsKey('password'), isTrue);
    });

    testWidgets('400 은 비밀번호 입력칸의 errorText 로 남는다', (tester) async {
      final service = FakeSignUpService(
        signUpMode: FakeSignUpMode.invalidPassword,
      );
      final session = await pumpSignUp(tester, service: service);

      await fillValidForm(tester);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // 로컬 validator 를 통과한 값인데도 서버가 거부했으므로 에러가 남는다.
      expect(
        find.text('비밀번호는 대문자/소문자/숫자/특수문자를 포함한 8자 이상이어야 합니다.'),
        findsOneWidget,
      );
      expect(session.memberId, isNull);

      // 비밀번호를 고치면 그 문구가 사라진다.
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'Another123!',
      );
      await tester.pumpAndSettle();
      expect(
        find.text('비밀번호는 대문자/소문자/숫자/특수문자를 포함한 8자 이상이어야 합니다.'),
        findsNothing,
      );
    });

    testWidgets('409 는 Snackbar 로 보여주고 입력을 지우지 않는다', (tester) async {
      final service = FakeSignUpService(signUpMode: FakeSignUpMode.duplicated);
      await pumpSignUp(tester, service: service);

      await fillValidForm(tester);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('이미 사용 중인 이메일입니다.'), findsOneWidget);
      expect(find.text('무비러버'), findsOneWidget);
      expect(find.text('movie@example.com'), findsOneWidget);
    });

    testWidgets('제출 중에는 버튼이 잠기고 화면을 벗어날 수 없다', (tester) async {
      final service = FakeSignUpService(delay: loadingDelay);
      await pumpSignUp(tester, service: service);

      await fillValidForm(tester);
      await tester.tap(submitButton);
      await tester.pump();

      final button = tester.widget<MovieLogButton>(submitButton);
      expect(button.isLoading, isTrue);

      // PopScope 가 뒤로가기를 막는다. (Challenge)
      expect(
        find.byWidgetPredicate((widget) => widget is PopScope && !widget.canPop),
        findsOneWidget,
      );

      // 연속 탭이 두 번째 요청이 되지 않는다.
      await tester.tap(submitButton, warnIfMissed: false);
      await tester.pumpAndSettle(loadingDelay);

      expect(service.signUpCalls, hasLength(1));
    });
  });
}

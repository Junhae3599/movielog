// SignUpViewModel(닉네임·이메일 중복 확인) 테스트

import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/view_models/sign_up_view_model.dart';

import 'fakes/fake_sign_up_service.dart';

void main() {
  group('중복 확인 상태', () {
    test('available: true 면 사용 가능 상태가 되고 에러 문구가 없다', () async {
      final service = FakeSignUpService();
      final viewModel = SignUpViewModel(service);

      expect(viewModel.nicknameCheckStatus, equals(CheckStatus.idle));

      viewModel.onNicknameChanged('무비러버');
      await viewModel.checkNickname('무비러버');

      expect(viewModel.nicknameCheckStatus, equals(CheckStatus.available));
      expect(viewModel.nicknameErrorText, isNull);
      expect(service.nicknameCalls, equals(['무비러버']));
    });

    test('available: false 면 중복 상태가 되고 버튼을 더 누를 수 없다', () async {
      final viewModel = SignUpViewModel(
        FakeSignUpService(nicknameMode: FakeCheckMode.duplicated),
      );

      viewModel.onNicknameChanged('무비러버');
      await viewModel.checkNickname('무비러버');

      expect(viewModel.nicknameCheckStatus, equals(CheckStatus.duplicated));
      expect(viewModel.nicknameErrorText, equals('이미 사용 중인 닉네임입니다.'));
      expect(viewModel.canCheckNickname, isFalse);
    });

    test('통신 실패와 정상 중복 응답은 다른 상태·문구로 구분된다', () async {
      final duplicated = SignUpViewModel(
        FakeSignUpService(nicknameMode: FakeCheckMode.duplicated),
      );
      duplicated.onNicknameChanged('무비러버');
      await duplicated.checkNickname('무비러버');

      final failed = SignUpViewModel(
        FakeSignUpService(nicknameMode: FakeCheckMode.failure),
      );
      failed.onNicknameChanged('무비러버');
      await failed.checkNickname('무비러버');

      expect(failed.nicknameCheckStatus, equals(CheckStatus.error));
      expect(failed.nicknameErrorText, equals('중복 확인에 실패했어요. 다시 시도해 주세요.'));
      expect(
        failed.nicknameErrorText,
        isNot(equals(duplicated.nicknameErrorText)),
      );
      // 통신 실패는 다시 시도할 수 있어야 한다. (중복과 달리 버튼이 살아 있다)
      expect(failed.canCheckNickname, isTrue);
    });

    test('통신 중에는 checking 상태가 되고 버튼을 누를 수 없다', () async {
      final viewModel = SignUpViewModel(
        FakeSignUpService(delay: const Duration(milliseconds: 50)),
      );

      viewModel.onNicknameChanged('무비러버');
      final pending = viewModel.checkNickname('무비러버');

      expect(viewModel.nicknameCheckStatus, equals(CheckStatus.checking));
      expect(viewModel.canCheckNickname, isFalse);

      await pending;
      expect(viewModel.nicknameCheckStatus, equals(CheckStatus.available));
    });

    test('빈 값으로는 요청을 보내지 않는다', () async {
      final service = FakeSignUpService();
      final viewModel = SignUpViewModel(service);

      viewModel.onNicknameChanged('   ');
      await viewModel.checkNickname('   ');

      expect(service.nicknameCalls, isEmpty);
      expect(viewModel.nicknameCheckStatus, equals(CheckStatus.idle));
    });
  });

  group('입력 변경 시 무효화', () {
    test('입력을 바꾸면 이전 확인 결과가 idle 로 돌아간다', () async {
      final viewModel = SignUpViewModel(FakeSignUpService());

      viewModel.onNicknameChanged('무비러버');
      await viewModel.checkNickname('무비러버');
      expect(viewModel.nicknameCheckStatus, equals(CheckStatus.available));

      viewModel.onNicknameChanged('무비러버2');

      expect(viewModel.nicknameCheckStatus, equals(CheckStatus.idle));
      expect(viewModel.nicknameErrorText, isNull);
      expect(viewModel.canCheckNickname, isTrue);
    });

    test('중복이었던 값을 다시 입력하면 재요청 없이 바로 에러가 된다', () async {
      final service = FakeSignUpService(
        nicknameMode: FakeCheckMode.duplicated,
      );
      final viewModel = SignUpViewModel(service);

      viewModel.onNicknameChanged('무비러버');
      await viewModel.checkNickname('무비러버');
      expect(viewModel.nicknameCheckStatus, equals(CheckStatus.duplicated));

      // 값을 바꾸는 동안에는 Form 이 원래 상태로 돌아온다.
      viewModel.onNicknameChanged('무비');
      expect(viewModel.nicknameCheckStatus, equals(CheckStatus.idle));

      // 중복이었던 값을 그대로 다시 입력.
      viewModel.onNicknameChanged('무비러버');

      expect(viewModel.nicknameCheckStatus, equals(CheckStatus.duplicated));
      expect(viewModel.nicknameErrorText, equals('이미 사용 중인 닉네임입니다.'));
      // 서버에는 한 번만 물었다.
      expect(service.nicknameCalls, equals(['무비러버']));
    });

    test('앞뒤 공백만 다른 값은 같은 값으로 본다', () async {
      final service = FakeSignUpService(
        nicknameMode: FakeCheckMode.duplicated,
      );
      final viewModel = SignUpViewModel(service);

      viewModel.onNicknameChanged('무비러버');
      await viewModel.checkNickname('무비러버');

      viewModel.onNicknameChanged(' 무비러버 ');

      expect(viewModel.nicknameCheckStatus, equals(CheckStatus.duplicated));
      expect(service.nicknameCalls, equals(['무비러버']));
    });

    test('응답을 기다리는 동안 입력이 바뀌면 그 응답을 버린다', () async {
      final viewModel = SignUpViewModel(
        FakeSignUpService(delay: const Duration(milliseconds: 50)),
      );

      viewModel.onNicknameChanged('무비러버');
      final pending = viewModel.checkNickname('무비러버');

      // 응답이 오기 전에 다른 값으로 바꾼다.
      viewModel.onNicknameChanged('다른닉네임');
      await pending;

      // 늦게 도착한 '무비러버' 의 결과가 현재 입력의 상태를 덮어쓰지 않는다.
      expect(viewModel.nicknameCheckStatus, equals(CheckStatus.idle));
    });
  });

  group('닉네임과 이메일은 서로 영향을 주지 않는다', () {
    test('닉네임이 중복이어도 이메일 상태는 그대로다', () async {
      final viewModel = SignUpViewModel(
        FakeSignUpService(
          nicknameMode: FakeCheckMode.duplicated,
          emailMode: FakeCheckMode.available,
        ),
      );

      viewModel.onNicknameChanged('무비러버');
      viewModel.onEmailChanged('movie@example.com');
      await viewModel.checkNickname('무비러버');
      await viewModel.checkEmail('movie@example.com');

      expect(viewModel.nicknameCheckStatus, equals(CheckStatus.duplicated));
      expect(viewModel.emailCheckStatus, equals(CheckStatus.available));
      expect(viewModel.emailErrorText, isNull);
      expect(viewModel.canCheckEmail, isTrue);
    });

    test('한쪽이라도 중복이거나 확인 중이면 가입을 막는다', () async {
      final viewModel = SignUpViewModel(
        FakeSignUpService(emailMode: FakeCheckMode.duplicated),
      );

      expect(viewModel.isBlockedByCheck, isFalse);

      viewModel.onEmailChanged('movie@example.com');
      await viewModel.checkEmail('movie@example.com');

      expect(viewModel.isBlockedByCheck, isTrue);
    });
  });

  test('dispose 뒤에 도착한 응답은 상태를 건드리지 않는다', () async {
    final viewModel = SignUpViewModel(
      FakeSignUpService(delay: const Duration(milliseconds: 50)),
    );

    viewModel.onNicknameChanged('무비러버');
    final pending = viewModel.checkNickname('무비러버');
    viewModel.dispose();

    // dispose 뒤 notifyListeners 를 부르면 예외가 난다. 그것 없이 끝나야 한다.
    await expectLater(pending, completes);
    expect(viewModel.nicknameCheckStatus, equals(CheckStatus.checking));
  });
}

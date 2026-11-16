// AuthViewModel — 로그인·세션 복원·만료·로그아웃 테스트 (8주차)
//
// 이 파일이 고정하는 규칙은 네 가지다.
//   1. Token 이 있다는 이유만으로 signedIn 이 되지 않는다. (서버 검증 필요)
//   2. 네트워크 실패로 Token 을 지우지 않는다. (401 과 구분)
//   3. 로그인 실패 401(AUTH401_1)과 보호 요청 401 을 같이 처리하지 않는다.
//   4. 이전 세션의 늦은 응답이 새 세션을 덮지 않는다.

import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/view_models/auth_view_model.dart';

import 'fakes/fake_auth.dart';
import 'fakes/movie_log_fixtures.dart';

AuthViewModel buildViewModel({
  FakeAuthApiService? authApi,
  FakeMemberApiService? memberApi,
  FakeTokenStorage? storage,
}) {
  return AuthViewModel(
    authApi ?? FakeAuthApiService(),
    memberApi ?? FakeMemberApiService(),
    storage ?? FakeTokenStorage(),
  );
}

void main() {
  group('restoreSession', () {
    test('initializing 에서 시작한다', () {
      // 저장소를 읽기 전에는 로그인/로그아웃 어느 쪽도 확정할 수 없다.
      expect(buildViewModel().status, AuthStatus.initializing);
    });

    test('저장된 Token 이 없으면 서버에 묻지 않고 signedOut 이다', () async {
      final memberApi = FakeMemberApiService();
      final viewModel = buildViewModel(memberApi: memberApi);

      await viewModel.restoreSession();

      expect(viewModel.status, AuthStatus.signedOut);
      expect(memberApi.fetchCount, 0);
    });

    test('Token 이 있으면 GET me 로 확인한 뒤에만 signedIn 이 된다', () async {
      final memberApi = FakeMemberApiService(
        member: fakeMemberInfo(nickname: '영화광'),
      );
      final viewModel = buildViewModel(
        memberApi: memberApi,
        storage: FakeTokenStorage(token: 'saved.token'),
      );

      await viewModel.restoreSession();

      expect(memberApi.fetchCount, 1);
      expect(viewModel.status, AuthStatus.signedIn);
      expect(viewModel.member?.nickname, '영화광');
    });

    test('AUTH401_4 는 Token 이 무효하다는 확답이므로 세션을 정리한다', () async {
      final storage = FakeTokenStorage(token: 'expired.token');
      final viewModel = buildViewModel(
        memberApi: FakeMemberApiService(fetchError: authError('AUTH401_4')),
        storage: storage,
      );

      await viewModel.restoreSession();

      expect(viewModel.status, AuthStatus.signedOut);
      expect(storage.deleteCount, 1);
      expect(storage.token, isNull);
      expect(viewModel.sessionExpired, isTrue);
    });

    test('네트워크 실패는 retryRequired 이고 Token 을 지우지 않는다', () async {
      final storage = FakeTokenStorage(token: 'valid.token');
      final viewModel = buildViewModel(
        memberApi: FakeMemberApiService(fetchError: networkError()),
        storage: storage,
      );

      await viewModel.restoreSession();

      // 지하철에서 앱을 켰다고 로그인 정보를 잃으면 안 된다.
      expect(viewModel.status, AuthStatus.retryRequired);
      expect(storage.deleteCount, 0);
      expect(storage.token, 'valid.token');
      expect(viewModel.sessionExpired, isFalse);
      expect(viewModel.message, contains('다시 시도'));
    });

    test('저장소를 읽지 못해도 Token 을 지우지 않는다', () async {
      final storage = FakeTokenStorage(token: 'valid.token', readThrows: true);
      final viewModel = buildViewModel(storage: storage);

      await viewModel.restoreSession();

      // 기기 저장소 실패는 서버의 401 과 다른 오류다.
      expect(viewModel.status, AuthStatus.retryRequired);
      expect(storage.deleteCount, 0);
      expect(viewModel.message, contains('저장소'));
    });
  });

  group('login', () {
    test('성공하면 Token 을 저장한 뒤 signedIn 이 된다', () async {
      final storage = FakeTokenStorage();
      final viewModel = buildViewModel(
        authApi: FakeAuthApiService(accessToken: 'new.token'),
        storage: storage,
      );

      await viewModel.login('movie@example.com', 'Umc1234!');

      // 저장이 끝나기 전에 signedIn 이 되면 보호 요청이 바로 401 을 받는다.
      expect(storage.saved, ['new.token']);
      expect(viewModel.status, AuthStatus.signedIn);
    });

    test('로그인 직후에는 GET me 를 부르지 않는다', () async {
      final memberApi = FakeMemberApiService();
      final viewModel = buildViewModel(memberApi: memberApi);

      await viewModel.login('movie@example.com', 'Umc1234!');

      // 내 정보는 MainShell 이 한 번 불러온다. 여기서 중복 호출하지 않는다.
      expect(memberApi.fetchCount, 0);
      expect(viewModel.loginNickname, isNotNull);
    });

    test('AUTH401_1 은 입력 오류 문구이고 만료 표시를 켜지 않는다', () async {
      final viewModel = buildViewModel(
        authApi: FakeAuthApiService(error: authError('AUTH401_1')),
      );

      await viewModel.login('movie@example.com', 'wrong');

      expect(viewModel.status, AuthStatus.signedOut);
      expect(viewModel.message, '이메일 또는 비밀번호를 확인해 주세요.');
      // 로그인 실패 한 번에 "로그인이 만료됐어요" Snackbar 가 뜨면 안 된다.
      expect(viewModel.sessionExpired, isFalse);
    });

    test('네트워크 실패는 입력 오류와 다른 문구를 쓴다', () async {
      final viewModel = buildViewModel(
        authApi: FakeAuthApiService(error: networkError(path: '/v7/auth/login')),
      );

      await viewModel.login('movie@example.com', 'Umc1234!');

      expect(viewModel.status, AuthStatus.signedOut);
      expect(viewModel.message, contains('잠시 후 다시 시도'));
    });

    test('요청 중에는 같은 로그인을 다시 보내지 않는다', () async {
      final authApi = FakeAuthApiService(
        delay: const Duration(milliseconds: 30),
      );
      final viewModel = buildViewModel(authApi: authApi);

      final pending = viewModel.login('movie@example.com', 'Umc1234!');
      expect(viewModel.status, AuthStatus.authenticating);

      await viewModel.login('movie@example.com', 'Umc1234!'); // 무시된다
      await pending;

      expect(authApi.calls, hasLength(1));
    });

    test('비밀번호는 toString 에 남지 않는다', () async {
      final authApi = FakeAuthApiService();
      final viewModel = buildViewModel(authApi: authApi);

      await viewModel.login('movie@example.com', 'Umc1234!');

      // 로그·예외 메시지로 비밀번호가 새 나가는 경로를 막는다.
      expect('${authApi.calls.single}', isNot(contains('Umc1234!')));
      expect('${authApi.calls.single}', contains('***'));
    });
  });

  group('loadMember', () {
    test('이미 member 를 들고 있으면 다시 묻지 않는다', () async {
      final memberApi = FakeMemberApiService();
      final viewModel = buildViewModel(
        memberApi: memberApi,
        storage: FakeTokenStorage(token: 'saved.token'),
      );
      await viewModel.restoreSession(); // 여기서 이미 1회 호출된다

      await viewModel.loadMember();

      expect(memberApi.fetchCount, 1);
    });

    test('force 를 주면 다시 묻는다', () async {
      final memberApi = FakeMemberApiService();
      final viewModel = buildViewModel(
        memberApi: memberApi,
        storage: FakeTokenStorage(token: 'saved.token'),
      );
      await viewModel.restoreSession();

      await viewModel.loadMember(force: true);

      expect(memberApi.fetchCount, 2);
    });

    test('401 이면 세션을 정리한다', () async {
      final storage = FakeTokenStorage();
      final memberApi = FakeMemberApiService();
      final viewModel = buildViewModel(memberApi: memberApi, storage: storage);
      await viewModel.login('movie@example.com', 'Umc1234!');

      memberApi.fetchError = authError('AUTH401_4');
      await viewModel.loadMember();

      expect(viewModel.status, AuthStatus.signedOut);
      expect(storage.deleteCount, 1);
    });

    test('네트워크 실패는 로그인 상태를 유지하고 error 로 남는다', () async {
      final storage = FakeTokenStorage();
      final memberApi = FakeMemberApiService();
      final viewModel = buildViewModel(memberApi: memberApi, storage: storage);
      await viewModel.login('movie@example.com', 'Umc1234!');

      memberApi.fetchError = networkError();
      await viewModel.loadMember();

      // 내 정보만 못 읽은 것이지 로그인이 끝난 것이 아니다.
      expect(viewModel.status, AuthStatus.signedIn);
      expect(viewModel.memberStatus, MemberLoadStatus.error);
      expect(storage.deleteCount, 0);
    });
  });

  group('로그아웃과 만료', () {
    test('직접 로그아웃은 만료 표시를 켜지 않는다', () async {
      final storage = FakeTokenStorage();
      final viewModel = buildViewModel(storage: storage);
      await viewModel.login('movie@example.com', 'Umc1234!');

      await viewModel.logout();

      expect(viewModel.status, AuthStatus.signedOut);
      expect(viewModel.member, isNull);
      expect(storage.deleteCount, 1);
      // 직접 나간 사용자에게 "만료됐어요" 라고 알릴 이유가 없다.
      expect(viewModel.sessionExpired, isFalse);
    });

    test('expireSession 은 만료 표시를 켜고 한 번만 소비된다', () async {
      final viewModel = buildViewModel();
      await viewModel.login('movie@example.com', 'Umc1234!');

      await viewModel.expireSession();
      expect(viewModel.sessionExpired, isTrue);

      viewModel.consumeSessionExpired();
      expect(viewModel.sessionExpired, isFalse);
    });

    test('세션이 끝날 때마다 sessionVersion 이 올라간다', () async {
      final viewModel = buildViewModel();
      final before = viewModel.sessionVersion;

      await viewModel.login('movie@example.com', 'Umc1234!');
      await viewModel.logout();

      expect(viewModel.sessionVersion, greaterThan(before));
    });
  });

  test('이전 세션의 늦은 응답이 새 세션을 지우지 않는다', () async {
    final storage = FakeTokenStorage(token: 'old.token');
    final memberApi = FakeMemberApiService(
      fetchError: authError('AUTH401_4'),
      delay: const Duration(milliseconds: 40),
    );
    final viewModel = buildViewModel(memberApi: memberApi, storage: storage);

    // 이전 세션의 GET me 가 아직 날아가고 있는 동안 새로 로그인한다.
    final stale = viewModel.restoreSession();
    await viewModel.login('new@example.com', 'Umc1234!');
    expect(viewModel.status, AuthStatus.signedIn);

    await stale;

    // 늦게 도착한 401 이 방금 만든 세션을 끝내면 안 된다.
    expect(viewModel.status, AuthStatus.signedIn);
    expect(storage.deleteCount, 0);
  });
}

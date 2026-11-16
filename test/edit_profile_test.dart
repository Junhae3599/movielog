// 프로필 수정 — 오류를 어디에 보여줄지 가르는 테스트 (8주차)
//
// 닉네임 길이·중복은 **입력칸 아래**, 네트워크 실패는 **Snackbar**,
// 세션 만료는 **세션 정리 + 로그인 화면**이다. 하나로 묶으면 네트워크 오류가
// 닉네임 칸에 붙거나, 만료가 조용히 지나간다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:movielog/screens/profile/edit_profile_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/edit_profile_view_model.dart';
import 'package:movielog/widgets/movie_log_button.dart';

import 'fakes/fake_auth.dart';
import 'fakes/movie_log_fixtures.dart';
import 'test_helpers.dart';

/// 로그인한 상태의 (auth, memberApi) 한 쌍을 만든다.
Future<(AuthViewModel, FakeMemberApiService)> signedIn({
  String nickname = '무비러버',
}) async {
  final memberApi = FakeMemberApiService(
    member: fakeMemberInfo(nickname: nickname),
  );
  final auth = await signedInAuthViewModel(memberApi: memberApi);
  return (auth, memberApi);
}

void main() {
  group('EditProfileViewModel.save', () {
    test('2~12자를 벗어나면 요청을 보내지 않는다', () async {
      final (auth, memberApi) = await signedIn();
      final viewModel = EditProfileViewModel(memberApi, auth);

      expect(await viewModel.save('가'), isFalse);
      expect(viewModel.nicknameError, contains('2~12자'));
      expect(memberApi.updateCalls, isEmpty);

      expect(await viewModel.save('가' * 13), isFalse);
      expect(memberApi.updateCalls, isEmpty);
    });

    test('현재 닉네임과 같으면 요청 없이 성공으로 끝낸다', () async {
      final (auth, memberApi) = await signedIn(nickname: '무비러버');
      final viewModel = EditProfileViewModel(memberApi, auth);

      expect(await viewModel.save('무비러버'), isTrue);

      // 자기 자신은 중복 검사에서 빠지므로 409 는 아니지만, 보낼 이유도 없다.
      expect(memberApi.updateCalls, isEmpty);
      expect(viewModel.status, EditProfileStatus.success);
    });

    test('성공하면 GET me 없이 member 를 교체한다', () async {
      final (auth, memberApi) = await signedIn();
      final viewModel = EditProfileViewModel(memberApi, auth);
      final before = memberApi.fetchCount;

      expect(await viewModel.save('영화광'), isTrue);

      expect(memberApi.updateCalls, ['영화광']);
      // 수정 응답이 이미 최신 내 정보다.
      expect(memberApi.fetchCount, before);
      expect(auth.member?.nickname, '영화광');
    });

    test('MEMBER409_1 은 입력칸 오류로 남고 입력값을 유지한다', () async {
      final (auth, memberApi) = await signedIn();
      memberApi.updateError = commonError(
        requestOptionsOf('/v7/members/me'),
        409,
        'MEMBER409_1',
        '이미 사용 중인 닉네임입니다.',
      );
      final viewModel = EditProfileViewModel(memberApi, auth);

      expect(await viewModel.save('영화광'), isFalse);

      expect(viewModel.nicknameError, '이미 사용 중인 닉네임이에요.');
      expect(viewModel.message, isNull); // Snackbar 가 아니다
      expect(auth.status, AuthStatus.signedIn);
    });

    test('COMMON400 은 서버 문구를 그대로 입력칸에 쓴다', () async {
      final (auth, memberApi) = await signedIn();
      memberApi.updateError = commonError(
        requestOptionsOf('/v7/members/me'),
        400,
        'COMMON400',
        '닉네임은 2자 이상이어야 합니다.',
      );
      final viewModel = EditProfileViewModel(memberApi, auth);

      expect(await viewModel.save('영화광'), isFalse);

      expect(viewModel.nicknameError, '닉네임은 2자 이상이어야 합니다.');
    });

    test('네트워크 실패는 Snackbar 문구이고 로그아웃하지 않는다', () async {
      final (auth, memberApi) = await signedIn();
      memberApi.updateError = networkError();
      final viewModel = EditProfileViewModel(memberApi, auth);

      expect(await viewModel.save('영화광'), isFalse);

      expect(viewModel.nicknameError, isNull);
      expect(viewModel.message, contains('네트워크'));
      expect(auth.status, AuthStatus.signedIn);
    });

    test('AUTH401_4 는 세션을 정리하고 pop 하지 않는다', () async {
      final storage = FakeTokenStorage();
      final memberApi = FakeMemberApiService();
      final auth = await signedInAuthViewModel(
        memberApi: memberApi,
        storage: storage,
      );
      memberApi.updateError = authError('AUTH401_4');
      final viewModel = EditProfileViewModel(memberApi, auth);

      // false 를 돌려주므로 화면이 pop 하지 않는다. Router 가 /login 으로 보낸다.
      expect(await viewModel.save('영화광'), isFalse);

      expect(auth.status, AuthStatus.signedOut);
      expect(auth.sessionExpired, isTrue);
      expect(storage.deleteCount, 1);
    });

    test('저장 중에는 같은 요청을 다시 보내지 않는다', () async {
      final (auth, memberApi) = await signedIn();
      memberApi.delay = const Duration(milliseconds: 30);
      final viewModel = EditProfileViewModel(memberApi, auth);

      final pending = viewModel.save('영화광');
      expect(viewModel.isSaving, isTrue);

      await viewModel.save('영화광');
      await pending;

      expect(memberApi.updateCalls, hasLength(1));
    });
  });

  group('프로필 수정 화면', () {
    Future<FakeMemberApiService> pumpEditProfile(
      WidgetTester tester, {
      FakeMemberApiService? memberApi,
      AuthViewModel? auth,
    }) async {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final api = memberApi ??
          FakeMemberApiService(member: fakeMemberInfo(nickname: '무비러버'));
      final viewModel = auth ?? await signedInAuthViewModel(memberApi: api);

      // 화면이 성공·취소 뒤에 context.pop() 을 부르므로 GoRouter 가 필요하다.
      // 돌아간 곳이 어디인지만 보면 되니 목적지는 간단한 화면으로 둔다.
      final router = GoRouter(
        initialLocation: '/my/profile/edit',
        routes: [
          GoRoute(
            path: '/my',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('마이페이지'))),
            routes: [
              GoRoute(
                path: 'profile/edit',
                builder: (context, state) => const EditProfileScreen(),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthViewModel>.value(value: viewModel),
            ChangeNotifierProvider<EditProfileViewModel>(
              create: (_) => EditProfileViewModel(api, viewModel),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      return api;
    }

    testWidgets('이메일은 읽기 전용이고 닉네임만 편집할 수 있다', (tester) async {
      await pumpEditProfile(tester);

      expect(find.text('movie@example.com'), findsOneWidget);
      // 로그인 식별자라 수정 대상이 아니다.
      final fields = tester.widgetList<TextFormField>(find.byType(TextFormField));
      expect(fields.first.enabled, isFalse);
      expect(find.text('무비러버'), findsOneWidget);
    });

    testWidgets('중복 닉네임은 입력칸 아래에 남고 입력값은 지워지지 않는다', (tester) async {
      final api = FakeMemberApiService(
        member: fakeMemberInfo(nickname: '무비러버'),
      );
      api.updateError = commonError(
        requestOptionsOf('/v7/members/me'),
        409,
        'MEMBER409_1',
        '이미 사용 중인 닉네임입니다.',
      );
      await pumpEditProfile(tester, memberApi: api);

      await tester.enterText(find.byType(TextFormField).last, '영화광');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MovieLogButton, '저장'));
      await tester.pumpAndSettle();

      expect(find.text('이미 사용 중인 닉네임이에요.'), findsOneWidget);
      // 고쳐서 바로 다시 저장할 수 있도록 입력값을 유지한다.
      expect(find.text('영화광'), findsOneWidget);
    });

    testWidgets('변경 내용이 있으면 뒤로가기 전에 확인한다 (Challenge)', (tester) async {
      await pumpEditProfile(tester);

      await tester.enterText(find.byType(TextFormField).last, '영화광');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('수정을 취소할까요?'), findsOneWidget);

      // '계속 수정' 을 누르면 화면에 그대로 머무른다.
      await tester.tap(find.widgetWithText(TextButton, '계속 수정'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfileScreen), findsOneWidget);
      expect(find.text('영화광'), findsOneWidget);
    });

    testWidgets('바꾼 것이 없으면 확인 없이 나간다 (Challenge)', (tester) async {
      await pumpEditProfile(tester);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('수정을 취소할까요?'), findsNothing);
      expect(find.text('마이페이지'), findsOneWidget);
    });
  });
}

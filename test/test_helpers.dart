// 테스트 공용 헬퍼
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:movielog/core/storage/token_storage.dart';
import 'package:movielog/data/services/auth_api_service.dart';
import 'package:movielog/data/services/member_api_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/screens/sign_up/sign_up_screen.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/learning_member_session.dart';
import 'package:movielog/view_models/session_rating_store.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';

import 'fakes/fake_auth.dart';
import 'fakes/fake_rating_api_service.dart';
import 'fakes/fake_sign_up_service.dart';

/// SharedPreferencesAsync 를 기기 저장소 대신 메모리로 바꾼다.
/// 테스트마다 호출해 이전 테스트의 값이 남지 않게 한다.
void useInMemoryPreferences({Map<String, Object>? initial}) {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData(initial ?? {});
}

/// Loading 이 끝날 때까지 기다리는 여유 시간.
const loadingDelay = Duration(seconds: 2);

/// 테스트에서 "이미 가입을 마친 학습용 회원" 으로 쓰는 id.
///
/// 6주차의 상수 1 과 다른 값이라, 화면이 세션의 memberId 가 아니라 옛 상수를
/// 계속 쓰고 있으면 테스트가 바로 깨진다.
const testMemberId = 7;

/// 테스트에서 쓰는 로그인 계정의 이메일.
///
/// `LearningMemberSession` 이 **가입한 회원과 로그인한 회원이 같을 때만**
/// memberId 를 돌려주므로, 둘을 같은 값으로 맞춰야 공개 조회 경로가 열린다.
const testMemberEmail = 'movie@example.com';

/// 앱 최상단의 MultiProvider 를 테스트에서도 같은 모양으로 올린다.
///
/// Route 안의 ChangeNotifierProvider 가 `context.read<TmdbMovieService>()` 처럼
/// 공용 Service 를 찾기 때문에, 이것 없이 Router 를 띄우면 오류가 난다.
///
/// 8주차에는 [AuthViewModel] 과 [SessionRatingStore] 가 더해졌다. Router 의
/// `redirect` 가 인증 상태를 보기 때문에, 이것 없이는 어떤 화면도 뜨지 않는다.
/// [memberId] 를 주면 이미 학습용 회원가입을 마친 상태로 시작한다.
Widget withServices(
  TmdbMovieService service, {
  SignUpService? signUpService,
  RatingApiService? ratingApiService,
  AuthApiService? authApiService,
  MemberApiService? memberApiService,
  TokenStorage? tokenStorage,
  AuthViewModel? authViewModel,
  int? memberId,
  required Widget child,
}) {
  final auth = authViewModel ??
      AuthViewModel(
        authApiService ?? FakeAuthApiService(),
        memberApiService ?? FakeMemberApiService(),
        tokenStorage ?? FakeTokenStorage(),
      );

  return MultiProvider(
    providers: [
      Provider<TmdbMovieService>.value(value: service),
      Provider<SignUpService>.value(
        value: signUpService ?? FakeSignUpService(),
      ),
      Provider<RatingApiService>.value(
        value: ratingApiService ?? FakeRatingApiService(),
      ),
      Provider<AuthApiService>.value(
        value: authApiService ?? FakeAuthApiService(),
      ),
      Provider<MemberApiService>.value(
        value: memberApiService ?? FakeMemberApiService(),
      ),
      ChangeNotifierProvider<AuthViewModel>.value(value: auth),
      ChangeNotifierProvider<LearningMemberSession>(
        create: (_) {
          final session = LearningMemberSession();
          if (memberId != null) {
            session.remember(memberId: memberId, email: testMemberEmail);
          }
          return session;
        },
      ),
      ChangeNotifierProxyProvider<AuthViewModel, SessionRatingStore>(
        create: (_) => SessionRatingStore(),
        update: (_, viewModel, store) =>
            (store ?? SessionRatingStore())..syncSession(viewModel.sessionVersion),
      ),
    ],
    child: child,
  );
}

/// 이미 로그인을 마친 [AuthViewModel] 을 만든다.
///
/// Router 테스트는 `signedIn` 에서 시작해야 보호 화면을 볼 수 있다.
/// 실제 앱과 같은 경로(로그인 → Token 저장 → signedIn)를 거치게 해, 상태를
/// 직접 대입하는 지름길을 만들지 않는다.
Future<AuthViewModel> signedInAuthViewModel({
  FakeAuthApiService? authApi,
  FakeMemberApiService? memberApi,
  FakeTokenStorage? storage,
}) async {
  final viewModel = AuthViewModel(
    authApi ?? FakeAuthApiService(),
    memberApi ?? FakeMemberApiService(),
    storage ?? FakeTokenStorage(),
  );
  await viewModel.login(testMemberEmail, 'Umc1234!');
  await viewModel.loadMember();
  return viewModel;
}

/// 회원가입 화면을 ViewModel 과 함께 올린다.
///
/// 앱에서는 `/sign-up` Route 의 ChangeNotifierProvider 가 이 일을 한다.
/// 화면만 따로 띄우는 테스트도 같은 모양을 쓰도록 모아 두었다.
/// 가입 성공 시 화면이 memberId 를 담는 세션도 함께 올린다.
Widget signUpScreen({SignUpService? service, LearningMemberSession? session}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SignUpViewModel>(
        create: (_) => SignUpViewModel(service ?? FakeSignUpService()),
      ),
      ChangeNotifierProvider<LearningMemberSession>.value(
        value: session ?? LearningMemberSession(),
      ),
    ],
    child: const SignUpScreen(),
  );
}

// 테스트 공용 헬퍼
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/screens/sign_up/sign_up_screen.dart';
import 'package:movielog/view_models/learning_member_session.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';

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

/// 앱 최상단의 MultiProvider 를 테스트에서도 같은 모양으로 올린다.
///
/// Route 안의 ChangeNotifierProvider 가 `context.read<TmdbMovieService>()` 처럼
/// 공용 Service 를 찾기 때문에, 이것 없이 Router 를 띄우면 오류가 난다.
///
/// 자체 백엔드 Service 는 대부분의 테스트에서 쓰이지 않으므로 기본 Fake 를 둔다.
/// [memberId] 를 주면 이미 학습용 회원가입을 마친 상태로 시작한다.
Widget withServices(
  TmdbMovieService service, {
  SignUpService? signUpService,
  RatingApiService? ratingApiService,
  int? memberId,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      Provider<TmdbMovieService>.value(value: service),
      Provider<SignUpService>.value(
        value: signUpService ?? FakeSignUpService(),
      ),
      Provider<RatingApiService>.value(
        value: ratingApiService ?? FakeRatingApiService(),
      ),
      ChangeNotifierProvider<LearningMemberSession>(
        create: (_) {
          final session = LearningMemberSession();
          if (memberId != null) session.setMemberId(memberId);
          return session;
        },
      ),
    ],
    child: child,
  );
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

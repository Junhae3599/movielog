// 테스트 공용 헬퍼
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:movielog/data/services/member_check_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/screens/sign_up/sign_up_screen.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';

import 'fakes/fake_member_check_service.dart';
import 'fakes/fake_rating_api_service.dart';

/// SharedPreferencesAsync 를 기기 저장소 대신 메모리로 바꾼다.
/// 테스트마다 호출해 이전 테스트의 값이 남지 않게 한다.
void useInMemoryPreferences({Map<String, Object>? initial}) {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData(initial ?? {});
}

/// Loading 이 끝날 때까지 기다리는 여유 시간.
const loadingDelay = Duration(seconds: 2);

/// 앱 최상단의 MultiProvider 를 테스트에서도 같은 모양으로 올린다.
///
/// Route 안의 ChangeNotifierProvider 가 `context.read<TmdbMovieService>()` 처럼
/// 공용 Service 를 찾기 때문에, 이것 없이 Router 를 띄우면 오류가 난다.
///
/// 자체 백엔드 Service 는 대부분의 테스트에서 쓰이지 않으므로 기본 Fake 를 둔다.
Widget withServices(
  TmdbMovieService service, {
  MemberCheckService? memberCheckService,
  RatingApiService? ratingApiService,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      Provider<TmdbMovieService>.value(value: service),
      Provider<MemberCheckService>.value(
        value: memberCheckService ?? FakeMemberCheckService(),
      ),
      Provider<RatingApiService>.value(
        value: ratingApiService ?? FakeRatingApiService(),
      ),
    ],
    child: child,
  );
}

/// 회원가입 화면을 ViewModel 과 함께 올린다.
///
/// 앱에서는 `/sign-up` Route 의 ChangeNotifierProvider 가 이 일을 한다.
/// 화면만 따로 띄우는 테스트도 같은 모양을 쓰도록 모아 두었다.
Widget signUpScreen({MemberCheckService? service}) {
  return ChangeNotifierProvider<SignUpViewModel>(
    create: (_) => SignUpViewModel(service ?? FakeMemberCheckService()),
    child: const SignUpScreen(),
  );
}

// lib/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/services/member_api_service.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/sign_up_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../screens/home/home_screen.dart';
import '../screens/login/login_screen.dart';
import '../screens/main_shell.dart';
import '../screens/movie_detail/movie_detail_loader.dart';
import '../screens/movies/movie_list_screen.dart';
import '../screens/my_ratings/my_ratings_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/sign_up/sign_up_screen.dart';
import '../start_screen.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/edit_profile_view_model.dart';
import '../view_models/learning_member_session.dart';
import '../view_models/movie_home_view_model.dart';
import '../view_models/movie_list_view_model.dart';
import '../view_models/my_ratings_view_model.dart';
import '../view_models/session_rating_store.dart';
import '../view_models/sign_up_view_model.dart';

/// 상세 화면을 NavigationBar 위에 전체 화면으로 띄우기 위한 최상위 Navigator.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// 로그인하지 않아도 볼 수 있는 화면.
///
/// 회원가입은 로그인하기 **전에** 거치는 화면이므로 여기에 있어야 한다.
/// 빠뜨리면 가입하려는 사용자가 로그인 화면으로 되돌려진다.
const _publicPaths = {'/login', '/sign-up'};

/// 스플래시(세션 확인) 화면의 경로.
const _startPath = '/';

/// 인증 상태만 보고 어느 경로로 보낼지 정한다.
///
/// 화면 코드가 "로그인에 성공했으니 홈으로 간다" 를 직접 하지 않는 이유는,
/// 로그인·로그아웃·Token 만료가 **모두 같은 결론(어느 화면을 보여줄지)** 에
/// 도달해야 하기 때문이다. 세 곳에 흩어 놓으면 하나만 빠뜨려도 로그아웃한 뒤
/// 보호 화면이 그대로 남는다.
///
/// 여기서는 상태만 읽고 판단한다. API 호출 같은 비동기 작업은 하지 않는다.
/// (`redirect` 는 이동할 때마다 불리므로 요청을 넣으면 화면 이동마다 통신한다)
String? authRedirect(AuthStatus status, String location) {
  final atStart = location == _startPath;
  final atPublic = _publicPaths.contains(location);

  return switch (status) {
    // 확인 중 / 확인 실패(재시도 버튼): 스플래시를 유지한다.
    // 저장소를 읽기 전에 로그인이나 홈을 잠깐 보여주면 화면이 튄다.
    AuthStatus.initializing ||
    AuthStatus.retryRequired =>
      atStart ? null : _startPath,

    // 로그아웃 / 로그인 요청 중: 공개 화면만 허용한다.
    AuthStatus.signedOut ||
    AuthStatus.authenticating =>
      atPublic ? null : '/login',

    // 로그인됨: 스플래시와 로그인·회원가입 화면은 홈으로 보낸다.
    AuthStatus.signedIn => (atStart || atPublic) ? '/home' : null,
  };
}

/// 하단 탭 index 를 현재 경로에서 구한다.
int indexFromLocation(String path) {
  if (path.startsWith('/movies')) return 1;
  if (path.startsWith('/my')) return 2;
  return 0;
}

/// Router 를 만든다.
///
/// 8주차에 `final appRouter = GoRouter(...)` 상수에서 함수로 바꿨다.
/// `redirect` 는 **이동할 때만** 호출되므로, 상태가 바뀌었을 때 다시 검사하려면
/// `refreshListenable` 에 [AuthViewModel] 을 연결해야 한다. 그러려면 Router 가
/// 그 인스턴스를 알아야 한다.
GoRouter createRouter(AuthViewModel authViewModel) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: _startPath,
    // 인증 상태가 바뀌면 redirect 를 다시 실행한다.
    refreshListenable: authViewModel,
    redirect: (context, state) =>
        authRedirect(authViewModel.status, state.uri.path),
    routes: [
      GoRoute(
        // 스플래시: Token 확인 중 / 확인 실패 시 재시도.
        path: _startPath,
        builder: (context, state) {
          final auth = context.watch<AuthViewModel>();
          return StartScreen(
            message: auth.message,
            // retryRequired 일 때만 버튼을 준다. 확인 중에는 인디케이터다.
            onRetry: auth.status == AuthStatus.retryRequired
                ? auth.restoreSession
                : null,
          );
        },
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/sign-up',
        builder: (context, state) => ChangeNotifierProvider<SignUpViewModel>(
          create: (context) => SignUpViewModel(context.read<SignUpService>()),
          child: const SignUpScreen(),
        ),
      ),
      // 탭마다 Navigator 를 따로 두어 탭을 옮겨도 각 탭의 상태가 유지된다.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) =>
                    ChangeNotifierProvider<MovieHomeViewModel>(
                  create: (context) => MovieHomeViewModel(
                    context.read<TmdbMovieService>(),
                  )..loadPopular(),
                  child: const HomeScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/movies',
                builder: (context, state) =>
                    ChangeNotifierProvider<MovieListViewModel>(
                  create: (context) => MovieListViewModel(
                    context.read<TmdbMovieService>(),
                  )..loadInitial(),
                  child: const MovieListScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    // 최종 경로: /my/ratings
                    path: 'ratings',
                    // root Navigator 위에 push 해 NavigationBar 를 가린다.
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final auth = context.read<AuthViewModel>();

                      // 공개 조회에 쓸 memberId 는 이번 세션에 가입한 회원일
                      // 때만 알 수 있다. 모르면 null 을 넘기고, ViewModel 이
                      // 이번 세션에 등록한 평점만 보여준다.
                      final memberId = context
                          .read<LearningMemberSession>()
                          .memberIdFor(auth.member?.email);

                      return ChangeNotifierProvider<MyRatingsViewModel>(
                        create: (context) => MyRatingsViewModel(
                          context.read<RatingApiService>(),
                          context.read<TmdbMovieService>(),
                          auth,
                          context.read<SessionRatingStore>(),
                          memberId: memberId,
                        )..load(),
                        child: const MyRatingsScreen(),
                      );
                    },
                  ),
                  GoRoute(
                    // 최종 경로: /my/profile/edit
                    path: 'profile/edit',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final auth = context.watch<AuthViewModel>();

                      // 내 정보를 아직 못 받았으면 수정할 값이 없다.
                      // 빈 입력창을 열어 두면 사용자가 그 빈 값을 저장한다.
                      if (auth.member == null) {
                        return _EditProfilePlaceholder(auth: auth);
                      }

                      return ChangeNotifierProvider<EditProfileViewModel>(
                        create: (context) => EditProfileViewModel(
                          context.read<MemberApiService>(),
                          auth,
                        ),
                        child: const EditProfileScreen(),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/movies/:movieId',
        // NavigationBar 를 덮고 전체 화면으로 열린다.
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          // 경로에는 TMDB 가 부여한 영화 id 가 그대로 들어간다.
          // 이 값이 평점 저장 시 자체 백엔드의 movieId 가 된다.
          final id = int.tryParse(state.pathParameters['movieId'] ?? '');
          if (id == null || id < 1) {
            return const Scaffold(
              body: Center(child: Text('영화 ID가 올바르지 않습니다.')),
            );
          }

          // 목록에서 이미 받아 둔 영화 정보를 함께 넘겨 다시 요청하지 않는다.
          // URL 로 직접 들어오면 extra 가 없으므로 Loader 가 TMDB 에 다시 묻는다.
          final extra = state.extra;
          return MovieDetailLoader(
            movieId: id,
            initialMovie: extra is TmdbMovieDto && extra.id == id ? extra : null,
          );
        },
      ),
    ],
  );
}

/// 내 정보를 아직 못 받은 상태에서 프로필 수정 화면에 들어온 경우.
class _EditProfilePlaceholder extends StatelessWidget {
  const _EditProfilePlaceholder({required this.auth});

  final AuthViewModel auth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('프로필 수정')),
      body: Center(
        child: auth.memberStatus == MemberLoadStatus.error
            ? ElevatedButton(
                onPressed: () => auth.loadMember(force: true),
                child: const Text('다시 시도'),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}

// lib/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/services/member_check_service.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../screens/home/home_screen.dart';
import '../screens/main_shell.dart';
import '../screens/movie_detail/movie_detail_screen.dart';
import '../screens/movies/movie_list_screen.dart';
import '../screens/my_ratings/my_ratings_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/sign_up/sign_up_screen.dart';
import '../start_screen.dart';
import '../view_models/movie_home_view_model.dart';
import '../view_models/movie_list_view_model.dart';
import '../view_models/my_ratings_view_model.dart';
import '../view_models/sign_up_view_model.dart';

/// 상세 화면을 NavigationBar 위에 전체 화면으로 띄우기 위한 최상위 Navigator.
final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const StartScreen(),
    ),
    GoRoute(
      path: '/sign-up',
      builder: (context, state) => ChangeNotifierProvider<SignUpViewModel>(
        create: (context) => SignUpViewModel(context.read<MemberCheckService>()),
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
              // ChangeNotifierProvider 가 ViewModel 을 만들고,
              // Widget Tree 에서 사라질 때 dispose 까지 맡는다.
              // `..loadPopular()` 는 캐스케이드 연산자로, create 가 돌려준
              // 인스턴스에 바로 첫 로딩을 한 번 실행한다.
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
                  // 지정하지 않으면 자신이 속한 ShellRoute 의 Navigator 를 쓰게 되어
                  // 하단 NavigationBar 가 그대로 남는다. root Navigator 위에
                  // push 해 NavigationBar 를 가린 전체 화면으로 띄운다.
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) =>
                      ChangeNotifierProvider<MyRatingsViewModel>(
                    create: (context) => MyRatingsViewModel(
                      context.read<RatingApiService>(),
                      context.read<TmdbMovieService>(),
                      // 6주차는 로그인 전이므로 학습용 memberId 1 을 본다.
                      sampleMemberId,
                    )..load(),
                    child: const MyRatingsScreen(),
                  ),
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
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => MovieDetailScreen(
        // 경로에는 TMDB 가 부여한 영화 id 가 그대로 들어간다.
        // 이 값이 이후 평점 저장 시 자체 백엔드의 movieId 가 된다.
        movieId: int.tryParse(state.pathParameters['movieId'] ?? ''),
        // 목록에서 이미 받아 둔 영화 정보를 함께 넘겨 다시 요청하지 않는다.
        movie: state.extra is TmdbMovieDto ? state.extra as TmdbMovieDto : null,
      ),
    ),
  ],
);

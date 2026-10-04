// lib/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/home/home_screen.dart';
import '../screens/main_shell.dart';
import '../screens/movie_detail/movie_detail_screen.dart';
import '../screens/movies/movie_list_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/sign_up/sign_up_screen.dart';
import '../start_screen.dart';

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
      builder: (context, state) => const SignUpScreen(),
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
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/movies',
              builder: (context, state) => MovieListScreen(
                // 선택한 장르를 Query Parameter 로 표현한다.
                selectedGenres: _parseGenres(state.uri.queryParameters['genres']),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/my',
              builder: (context, state) => const ProfileScreen(),
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
        movieId: int.tryParse(state.pathParameters['movieId'] ?? ''),
      ),
    ),
  ],
);

/// "드라마,SF" 형태의 Query Parameter 를 집합으로 바꾼다.
Set<String> _parseGenres(String? raw) {
  if (raw == null || raw.isEmpty) return const {};
  return raw.split(',').where((genre) => genre.isNotEmpty).toSet();
}

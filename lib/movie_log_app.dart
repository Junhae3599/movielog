// lib/movie_log_app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/network/tmdb_client.dart';
import 'data/services/tmdb_movie_service.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class MovieLogApp extends StatelessWidget {
  const MovieLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiProvider 는 MaterialApp.router 를 감싸는 최상단에 둔다.
    //
    // GoRouter 는 화면을 옮길 때마다 그 Route 의 Widget Tree 를 새로 만든다.
    // Provider 가 특정 화면 하위에만 있으면 다른 Route 로 간 화면은
    // context.read 로 그것을 찾지 못하고 오류가 난다.
    //
    // 그래서 화면이 바뀌어도 유지되어야 하는 것(Dio Client, 공용 Service)만
    // 여기에 등록하고, 화면별 ViewModel 은 각 Route 안에서 만든다.
    return MultiProvider(
      providers: [
        Provider<TmdbMovieService>(
          create: (_) => TmdbMovieService(createTmdbClient()),
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'MovieLog',
        theme: AppTheme.light,
        routerConfig: appRouter,
      ),
    );
  }
}

// lib/movie_log_app.dart
import 'package:flutter/material.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';

class MovieLogApp extends StatelessWidget {
  const MovieLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    // GoRouter 를 쓰므로 MaterialApp 대신 MaterialApp.router 를 사용한다.
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'MovieLog',
      theme: AppTheme.light, // 공통 Theme 적용
      routerConfig: appRouter,
    );
  }
}

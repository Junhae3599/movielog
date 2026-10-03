// lib/movie_log_app.dart
import 'package:flutter/material.dart';
import 'screens/sign_up/sign_up_screen.dart';
import 'theme/app_theme.dart';

class MovieLogApp extends StatelessWidget {
  const MovieLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MovieLog',
      theme: AppTheme.light, // 공통 Theme 적용
      home: const SignUpScreen(), // 2주차 실습 화면
    );
  }
}

// lib/movie_log_app.dart
import 'package:flutter/material.dart';
import 'start_screen.dart'; // StartScreen 클래스 import

class MovieLogApp extends StatelessWidget {
  const MovieLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MovieLog',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
        scaffoldBackgroundColor: const Color(0xFFFAF9F5), // W0-01 배경색
      ),
      home: const StartScreen(), // 첫 실행 화면 지정
    );
  }
}

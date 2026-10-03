// lib/start_screen.dart
import 'package:flutter/material.dart'; // Material 패키지 import
import 'package:flutter_svg/flutter_svg.dart';

import 'theme/app_colors.dart';
import 'theme/app_text_styles.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32), // 좌우 여백
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Text(
                'FLUTTER 0주차',
                textAlign: TextAlign.center,
                style: AppTextStyles.label.copyWith(
                  letterSpacing: 2, // 자간을 넓혀 라벨처럼 표시
                  color: AppColors.bodyGray,
                ),
              ),
              const SizedBox(height: 56),
              // 0주차의 Icons.movie_outlined 를 실제 MovieLog 로고로 교체했다.
              SvgPicture.asset(
                'assets/logos/movielog_logo.svg',
                width: 72,
                height: 72,
                semanticsLabel: 'MovieLog 로고',
              ),
              const SizedBox(height: 64),
              Text(
                '영화의 순간을\n기록하세요', // 제목
                textAlign: TextAlign.center,
                style: AppTextStyles.headline.copyWith(
                  fontSize: 32,
                  height: 1.25, // 줄 간격
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '보고 싶은 영화부터 나만의 평점까지\n한곳에서 관리해요', // 설명
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(height: 1.4),
              ),
              const Spacer(), // 남은 공간을 밀어 버튼을 화면 아래에 배치
              ElevatedButton(
                onPressed: () {
                  // 0주차에는 로그만 출력하고 화면 이동은 구현하지 않습니다.
                  debugPrint('시작하기 버튼을 눌렀습니다.');
                },
                child: const Text('시작하기'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

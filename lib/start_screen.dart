// lib/start_screen.dart
import 'package:flutter/material.dart'; // Material 패키지 import

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
              const Text(
                'FLUTTER 0주차',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2, // 자간을 넓혀 라벨처럼 표시
                  color: Color(0xFF494551),
                ),
              ),
              const SizedBox(height: 56),
              const Icon(
                Icons.movie_outlined, // 0주차에는 로고 이미지 대신 기본 아이콘 사용
                size: 64,
                color: Color(0xFF6750A4),
              ),
              const SizedBox(height: 64),
              const Text(
                '영화의 순간을\n기록하세요', // 제목
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  height: 1.25, // 줄 간격
                  color: Color(0xFF1B1C1A),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '보고 싶은 영화부터 나만의 평점까지\n한곳에서 관리해요', // 설명
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                  height: 1.4,
                  color: Color(0xFF494551),
                ),
              ),
              const Spacer(), // 남은 공간을 밀어 버튼을 화면 아래에 배치
              ElevatedButton(
                onPressed: () {
                  // 0주차에는 로그만 출력하고 화면 이동은 구현하지 않습니다.
                  debugPrint('시작하기 버튼을 눌렀습니다.');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F378A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56), // 가로 전체, 높이 56
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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

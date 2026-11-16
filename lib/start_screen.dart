// lib/start_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'theme/app_colors.dart';
import 'theme/app_text_styles.dart';
import 'widgets/movie_log_button.dart';

/// 앱 시작 화면(Splash).
///
/// 1주차에 만든 시작 화면의 로고·제목·설명 레이아웃을 그대로 재사용한다.
/// 저장된 Token 을 확인하는 동안 빈 화면을 보여줄 수는 없고, 그렇다고
/// 로그인 화면을 잠깐 보여주면 **로그인되어 있는 사용자에게도 화면이 튄다.**
///
/// 8주차에 바뀐 것은 하단뿐이다. "시작하기" 버튼 자리에
/// - 확인 중([onRetry] 가 null)이면 인디케이터를,
/// - 확인 실패([onRetry] 가 있으면)면 안내 문구와 "다시 시도" 버튼을 둔다.
///
/// 확인 실패는 **로그아웃이 아니다.** 네트워크가 잠시 끊겼다고 유효한 Token 을
/// 지우면, 지하철에서 앱을 켠 사용자가 로그인 정보를 잃는다. 그래서 이 화면에
/// 머무르며 다시 시도하게 한다.
class StartScreen extends StatelessWidget {
  const StartScreen({super.key, this.message, this.onRetry});

  /// 확인 실패 안내 문구.
  final String? message;

  /// 다시 시도 콜백. null 이면 아직 확인 중이다.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Text(
                'FLUTTER 8주차',
                textAlign: TextAlign.center,
                style: AppTextStyles.label.copyWith(
                  letterSpacing: 2,
                  color: AppColors.bodyGray,
                ),
              ),
              const SizedBox(height: 56),
              SvgPicture.asset(
                'assets/logos/movielog_logo.svg',
                width: 72,
                height: 72,
                semanticsLabel: 'MovieLog 로고',
              ),
              const SizedBox(height: 64),
              Text(
                '영화의 순간을\n기록하세요',
                textAlign: TextAlign.center,
                style: AppTextStyles.headline.copyWith(
                  fontSize: 32,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '보고 싶은 영화부터 나만의 평점까지\n한곳에서 관리해요',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(height: 1.4),
              ),
              const Spacer(),
              // 1주차의 '시작하기' 버튼 자리. 두 상태 모두 같은 레이아웃을
              // 쓰므로 확인 중 → 실패로 바뀌어도 화면이 튀지 않는다.
              if (onRetry == null)
                const Center(child: CircularProgressIndicator())
              else ...[
                Text(
                  message ?? '로그인 상태를 확인하지 못했어요.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 12),
                MovieLogButton(
                  label: '다시 시도',
                  width: double.infinity,
                  onPressed: onRetry,
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// lib/screens/my_ratings/widgets/my_ratings_error.dart
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../widgets/movie_log_button.dart';

/// 평점을 불러오지 못했을 때의 화면.
///
/// DioException 을 그대로 노출하지 않고, ViewModel 이 status(400/404/그 밖)로
/// 구분해 둔 안내 문구와 다시 시도 버튼만 보여준다.
class MyRatingsError extends StatelessWidget {
  const MyRatingsError({super.key, required this.onRetry, this.message});

  final VoidCallback onRetry;
  final String? message;

  /// 다시 시도 버튼의 고정 너비.
  ///
  /// 문구 길이나 화면 폭에 따라 버튼 크기가 달라지지 않게 고정 값을 쓴다.
  /// (`width: null` 은 내용 기반, `double.infinity` 는 최대 너비)
  static const _retryWidth = 160.0;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 56, color: AppColors.gray),
            const SizedBox(height: 16),
            Text(
              '평점을 불러오지 못했어요',
              style: AppTextStyles.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message ?? '잠시 후 다시 시도해주세요.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            MovieLogButton(
              label: '다시 시도',
              width: _retryWidth,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

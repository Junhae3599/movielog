// lib/screens/movies/widgets/movie_list_error.dart
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// 불러오기에 실패했을 때의 화면.
///
/// Exception 이나 StackTrace 를 그대로 노출하지 않고, 사용자가 할 수 있는
/// 행동(다시 시도)을 함께 준다.
class MovieListError extends StatelessWidget {
  const MovieListError({super.key, required this.onRetry, this.isTimeout = false});

  final VoidCallback onRetry;

  /// 시간 초과인지 여부에 따라 안내 문구만 달라진다.
  final bool isTimeout;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 56, color: AppColors.gray),
            const SizedBox(height: 16),
            Text(
              isTimeout ? '응답이 너무 늦어요' : '목록을 불러오지 못했어요',
              style: AppTextStyles.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isTimeout
                  ? '네트워크 상태를 확인하고 다시 시도해주세요.'
                  : '잠시 후 다시 시도해주세요.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(160, 48),
              ),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}

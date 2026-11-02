// lib/screens/movies/widgets/movie_list_error.dart
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// 불러오기에 실패했을 때의 화면.
///
/// DioException 이나 StackTrace 를 그대로 노출하지 않는다.
/// ViewModel 이 만들어 둔 안내 문구와, 사용자가 할 수 있는 행동(다시 시도)만 보여준다.
class MovieListError extends StatelessWidget {
  const MovieListError({super.key, required this.onRetry, this.message});

  final VoidCallback onRetry;

  /// ViewModel 이 정한 안내 문구. 없으면 기본 문구를 쓴다.
  final String? message;

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
              '목록을 불러오지 못했어요',
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

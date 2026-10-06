// lib/screens/movies/widgets/movie_list_empty.dart
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// 불러오기는 성공했지만 보여줄 영화가 없을 때의 화면.
///
/// 빈 Grid 를 그대로 두지 않고 왜 비었는지와 다음에 할 수 있는 일을 알린다.
class MovieListEmpty extends StatelessWidget {
  const MovieListEmpty({super.key, this.onReset});

  /// 장르를 걸러서 비었을 때 전체 목록으로 돌아가는 버튼. null 이면 숨긴다.
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.movie_filter_outlined,
                size: 56, color: AppColors.gray),
            const SizedBox(height: 16),
            Text('조건에 맞는 영화가 없어요',
                style: AppTextStyles.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('다른 장르를 골라보세요.',
                style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
            if (onReset != null) ...[
              const SizedBox(height: 20),
              TextButton(onPressed: onReset, child: const Text('전체 보기')),
            ],
          ],
        ),
      ),
    );
  }
}

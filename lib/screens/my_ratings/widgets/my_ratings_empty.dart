// lib/screens/my_ratings/widgets/my_ratings_empty.dart
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// 불러오기는 성공했지만 등록된 평점이 없을 때의 화면.
///
/// 빈 배열 응답은 실패가 아니므로 Error 화면과 구분해서 보여준다.
class MyRatingsEmpty extends StatelessWidget {
  const MyRatingsEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_border, size: 56, color: AppColors.gray),
            const SizedBox(height: 16),
            Text(
              '아직 등록한 평점이 없어요',
              style: AppTextStyles.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '영화 상세 화면에서 별점을 남겨보세요.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

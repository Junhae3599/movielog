// lib/screens/my_ratings/widgets/my_ratings_loading.dart
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// 평점을 불러오는 동안 보여주는 화면.
///
/// 빈 화면 대신 카드 모양의 자리를 먼저 그려, 데이터가 도착했을 때
/// 레이아웃이 튀지 않게 한다.
class MyRatingsLoading extends StatelessWidget {
  const MyRatingsLoading({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => const _SkeletonCard(),
    );
  }
}

/// 실제 RatingCard 와 같은 높이로 자리만 차지하는 회색 카드.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bar(width: 64, height: 96, radius: 8),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bar(height: 16),
                const SizedBox(height: 10),
                _bar(height: 14, widthFactor: 0.4),
                const SizedBox(height: 10),
                _bar(height: 14, widthFactor: 0.7),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar({
    double? width,
    double? height,
    double widthFactor = 1,
    double radius = 6,
  }) {
    final bar = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.cardFill,
        borderRadius: BorderRadius.circular(radius),
      ),
    );

    if (widthFactor == 1) return bar;
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(widthFactor: widthFactor, child: bar),
    );
  }
}

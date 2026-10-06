// lib/screens/movies/widgets/movie_list_loading.dart
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// 목록을 불러오는 동안 보여주는 화면.
///
/// 빈 화면 대신 영화 카드 모양의 자리를 먼저 그려, 무엇이 로드되는지 알리고
/// 데이터가 도착했을 때 레이아웃이 튀지 않게 한다.
class MovieListLoading extends StatelessWidget {
  const MovieListLoading({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: itemCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 20,
        childAspectRatio: 0.62,
      ),
      itemBuilder: (context, index) => const _SkeletonCard(),
    );
  }
}

/// 실제 MovieCard 와 같은 비율로 자리만 차지하는 회색 카드.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _bar(radius: 12)),
        const SizedBox(height: 8),
        _bar(height: 16, widthFactor: 0.8),
        const SizedBox(height: 6),
        _bar(height: 13, widthFactor: 0.5),
      ],
    );
  }

  Widget _bar({double? height, double widthFactor = 1, double radius = 6}) {
    final bar = Container(
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

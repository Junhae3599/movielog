// lib/screens/profile/widgets/favorite_genres.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../theme/app_colors.dart';

/// 선호하는 장르를 Chip 으로 보여주는 영역.
class FavoriteGenres extends StatelessWidget {
  const FavoriteGenres({super.key, required this.genres});

  final List<String> genres;

  @override
  Widget build(BuildContext context) {
    return Column(
      // 교차축(가로) 왼쪽 정렬
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // 단색 SVG 라 colorFilter 로 테마 색을 입힌다.
            SvgPicture.asset(
              'assets/icons/movie.svg',
              width: 20,
              height: 20,
              colorFilter: const ColorFilter.mode(
                AppColors.violet,
                BlendMode.srcIn,
              ),
              semanticsLabel: '영화 아이콘',
            ),
            const SizedBox(width: 6),
            Text('선호하는 장르', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 16),
        // 장르 개수가 늘어나도 넘치지 않도록 Row 대신 Wrap 을 쓴다.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final genre in genres) Chip(label: Text(genre)),
          ],
        ),
      ],
    );
  }
}

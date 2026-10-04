// lib/widgets/movie_card.dart
import 'package:flutter/material.dart';

import '../data/movie.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 목록에서 영화 한 편을 보여주는 공통 카드.
class MovieCard extends StatelessWidget {
  const MovieCard({super.key, required this.movie, required this.onTap});

  final Movie movie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(movie.posterAsset, fit: BoxFit.cover),
                  ),
                ),
                // 포스터 오른쪽 위의 평점 배지
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.white),
                        const SizedBox(width: 2),
                        Text(
                          movie.rating.toStringAsFixed(1),
                          style: AppTextStyles.label.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            movie.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.fieldLabel,
          ),
          const SizedBox(height: 2),
          Text(
            '${movie.year} · ${movie.genres.first}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(
              fontSize: 14,
              color: AppColors.gray,
            ),
          ),
        ],
      ),
    );
  }
}

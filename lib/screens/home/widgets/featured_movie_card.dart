// lib/screens/home/widgets/featured_movie_card.dart
import 'package:flutter/material.dart';

import '../../../data/movie.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// 홈 상단의 추천 영화 카드.
class FeaturedMovieCard extends StatelessWidget {
  const FeaturedMovieCard({
    super.key,
    required this.movie,
    required this.onDetailTap,
  });

  final Movie movie;
  final VoidCallback onDetailTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDetailTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(movie.posterAsset, fit: BoxFit.cover),
              // 아래쪽 글자가 읽히도록 어둡게 덮는다.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.violet,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '추천 신작',
                        style: AppTextStyles.chip.copyWith(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      movie.title,
                      style: AppTextStyles.headline.copyWith(
                        color: Colors.white,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${movie.genreLabel} · ${movie.runtimeMinutes}분',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: onDetailTap,
                      icon: const Icon(Icons.info_outline, size: 20),
                      label: const Text('상세보기'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

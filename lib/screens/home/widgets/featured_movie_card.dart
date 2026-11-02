// lib/screens/home/widgets/featured_movie_card.dart
import 'package:flutter/material.dart';

import '../../../data/models/tmdb_movie_dto.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../widgets/tmdb_poster_image.dart';

/// 홈 상단의 추천 영화 카드. 인기 영화 1위를 크게 보여준다.
class FeaturedMovieCard extends StatelessWidget {
  const FeaturedMovieCard({
    super.key,
    required this.movie,
    required this.onDetailTap,
  });

  final TmdbMovieDto movie;
  final VoidCallback onDetailTap;

  /// "2024 · 평점 7.8" 처럼 있는 값만 모은다.
  String get _subtitle {
    final parts = <String>[
      if (movie.releaseYear != null) '${movie.releaseYear}',
      '평점 ${movie.voteAverage.toStringAsFixed(1)}',
    ];
    return parts.join(' · ');
  }

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
              TmdbPosterImage(posterPath: movie.posterPath),
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
                        '인기 1위',
                        style: AppTextStyles.chip.copyWith(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      movie.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headline.copyWith(
                        color: Colors.white,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitle,
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

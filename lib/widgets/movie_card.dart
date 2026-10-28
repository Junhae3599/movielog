// lib/widgets/movie_card.dart
import 'package:flutter/material.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'tmdb_poster_image.dart';

/// 목록에서 영화 한 편을 보여주는 공통 카드.
///
/// 5주차부터 Mock `Movie` 가 아니라 TMDB 응답 DTO 를 그대로 받는다.
class MovieCard extends StatelessWidget {
  const MovieCard({
    super.key,
    required this.movie,
    required this.onTap,
    required this.genreNames,
  });

  final TmdbMovieDto movie;
  final VoidCallback onTap;

  /// genre_ids 를 사람이 읽을 이름으로 바꾼 값. 비어 있으면 줄을 비워 둔다.
  final List<String> genreNames;

  /// "2024 · 드라마" 처럼 있는 값만 모아 보여준다.
  /// release_date 가 없으면 연도를 표시하지 않는다.
  String get _subtitle {
    final parts = <String>[
      if (movie.releaseYear != null) '${movie.releaseYear}',
      if (genreNames.isNotEmpty) genreNames.first,
    ];
    return parts.join(' · ');
  }

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
                  child: TmdbPosterImage(
                    posterPath: movie.posterPath,
                    borderRadius: BorderRadius.circular(12),
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
                          movie.voteAverage.toStringAsFixed(1),
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
            _subtitle,
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

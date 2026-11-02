// lib/screens/my_ratings/widgets/rating_card.dart
import 'package:flutter/material.dart';

import '../../../data/models/rating_with_movie.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../widgets/tmdb_poster_image.dart';

/// 평점 한 건을 보여주는 카드.
///
/// 평점(점수·후기·등록일)은 MovieLog 자체 백엔드의 값이고,
/// 제목·포스터는 TMDB 에서 가져온 값이다.
class RatingCard extends StatelessWidget {
  const RatingCard({super.key, required this.entry});

  final RatingWithMovie entry;

  static const _posterWidth = 64.0;
  static const _posterHeight = 96.0;

  /// "2026.09.06" 형식. UTC 로 내려오므로 기기 시간대로 바꿔 보여준다.
  String get _createdAt {
    final date = entry.rating.createdAt.toLocal();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}.$month.$day';
  }

  @override
  Widget build(BuildContext context) {
    final movie = entry.movie;
    final rating = entry.rating;
    final comment = rating.comment;

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
          // TMDB 에서 찾지 못한 영화는 posterPath 가 없으므로
          // TmdbPosterImage 가 그대로 placeholder 를 그린다.
          TmdbPosterImage(
            posterPath: movie?.posterPath,
            width: _posterWidth,
            height: _posterHeight,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // 영화 정보를 못 가져와도 평점은 남긴다. 제목 자리에는
                  // 어느 영화인지 알 수 있도록 movieId 를 그대로 보여준다.
                  movie?.title ?? '영화 정보 없음 (movieId ${rating.movieId})',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.fieldLabel,
                ),
                const SizedBox(height: 6),
                _ScoreStars(score: rating.score),
                if (comment != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    comment,
                    style: AppTextStyles.bodyMedium.copyWith(fontSize: 14),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  _createdAt,
                  style: AppTextStyles.label,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 정수 점수를 별 5개로 보여준다.
class _ScoreStars extends StatelessWidget {
  const _ScoreStars({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var star = 1; star <= 5; star++)
          Icon(
            star <= score ? Icons.star : Icons.star_border,
            size: 18,
            color: AppColors.violet,
          ),
        const SizedBox(width: 6),
        Text('$score', style: AppTextStyles.chip),
      ],
    );
  }
}

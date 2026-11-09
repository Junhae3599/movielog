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
///
/// 카드 오른쪽은 모드에 따라 달라진다. 기본 모드에서는 수정·삭제 버튼,
/// 편집(다중 선택) 모드에서는 CheckBox 다. 두 동작 모두 이 Widget 이 직접
/// 실행하지 않고 콜백으로 바깥에 넘긴다.
class RatingCard extends StatelessWidget {
  const RatingCard({
    super.key,
    required this.entry,
    this.onEdit,
    this.onDelete,
    this.isSelectable = false,
    this.isSelected = false,
    this.onSelectionChanged,
  });

  final RatingWithMovie entry;

  /// 기본 모드의 수정·삭제. null 이면 그 버튼을 그리지 않는다.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// 편집 모드 여부. true 면 수정·삭제 버튼 대신 CheckBox 를 보여준다.
  final bool isSelectable;
  final bool isSelected;
  final VoidCallback? onSelectionChanged;

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
        border: Border.all(
          color: isSelectable && isSelected ? AppColors.violet : AppColors.border,
        ),
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
          if (isSelectable)
            Checkbox(
              value: isSelected,
              onChanged: onSelectionChanged == null
                  ? null
                  : (_) => onSelectionChanged!(),
            )
          else
            _CardActions(onEdit: onEdit, onDelete: onDelete),
        ],
      ),
    );
  }
}

/// 카드 오른쪽의 수정·삭제 버튼.
///
/// 내가 작성한 평점만 보여주는 화면이므로 두 버튼을 함께 둔다. (서버도 403 으로
/// 남의 평점 수정·삭제를 거부한다)
class _CardActions extends StatelessWidget {
  const _CardActions({this.onEdit, this.onDelete});

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    if (onEdit == null && onDelete == null) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onEdit != null)
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: '수정',
            onPressed: onEdit,
          ),
        if (onDelete != null)
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: '삭제',
            onPressed: onDelete,
          ),
      ],
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

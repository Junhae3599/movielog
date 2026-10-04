// lib/screens/movie_detail/widgets/rating_dialog.dart
import 'package:flutter/material.dart';

import '../../../theme/app_text_styles.dart';
import '../../../widgets/movie_rating_input.dart';

/// 별점을 입력받는 커스텀 Dialog.
///
/// 저장을 누르면 고른 별점을, 그냥 닫으면 null 을 돌려준다.
class RatingDialog extends StatefulWidget {
  const RatingDialog({super.key, required this.movieTitle, this.initialRating});

  final String movieTitle;

  /// 이미 남긴 평점이 있으면 그 값에서 시작한다.
  final double? initialRating;

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  late double _rating = widget.initialRating ?? 0;

  bool get _canSave => _rating > 0;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.movieTitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '이 영화는 어땠나요?',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 20),
            MovieRatingInput(
              rating: _rating,
              onChanged: (value) => setState(() => _rating = value),
            ),
            const SizedBox(height: 16),
            Text(
              _canSave ? '${_rating.toStringAsFixed(1)} / 5.0' : '별을 눌러 선택해주세요',
              style: _canSave
                  ? AppTextStyles.statValue.copyWith(fontSize: 20)
                  : AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    // 고른 별점을 지워 처음부터 다시 고를 수 있다.
                    onPressed:
                        _canSave ? () => setState(() => _rating = 0) : null,
                    child: const Text('초기화'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _canSave ? () => Navigator.of(context).pop(_rating) : null,
                    child: const Text('저장'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

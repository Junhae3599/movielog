// lib/widgets/movie_rating_input.dart
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../theme/app_colors.dart';

/// 별점을 입력받는 위젯.
///
/// 입력 방법만 담당하고 실제 값은 부모가 들고 있는다.
///
/// 7주차 서버 연동부터는 **1~5 정수만** 고를 수 있다. v6 의 score 가 정수라서
/// 3주차의 반 점(0.5) 입력을 받아 두고 조용히 `toInt()` 로 깎으면, 사용자가 고른
/// 값과 저장되는 값이 달라진다. 그래서 입력 단계에서 막는다.
///
/// [rating]·[onChanged] 의 타입은 그대로 `double` 이다. `RatingBar.builder` 가
/// 항상 double 로 값을 돌려주기 때문이고, 이 설정에서는 1.0·2.0 처럼 정수를
/// 나타내는 double 만 전달된다.
class MovieRatingInput extends StatelessWidget {
  const MovieRatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
    this.enabled = true,
  });

  final double rating;
  final ValueChanged<double> onChanged;

  /// 저장 중에는 false 로 두어 별점을 바꾸지 못하게 한다.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return RatingBar.builder(
      initialRating: rating,
      minRating: 1,
      // false 면 별 한 개 단위로만 탭할 수 있다.
      allowHalfRating: false,
      ignoreGestures: !enabled,
      itemCount: 5,
      itemSize: 40,
      glow: false,
      itemBuilder: (context, index) =>
          const Icon(Icons.star, color: AppColors.violet),
      onRatingUpdate: onChanged,
    );
  }
}

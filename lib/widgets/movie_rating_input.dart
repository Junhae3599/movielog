// lib/widgets/movie_rating_input.dart
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

/// 별점을 입력받는 위젯.
///
/// 입력 방법만 담당하고 실제 값은 부모가 들고 있는다.
class MovieRatingInput extends StatelessWidget {
  const MovieRatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
  });

  final double rating;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return RatingBar.builder(
      initialRating: rating,
      minRating: 0.5,
      allowHalfRating: true, // 0.5 단위로 선택
      itemCount: 5,
      itemSize: 40,
      glow: false,
      itemBuilder: (context, index) =>
          const Icon(Icons.star, color: Colors.amber),
      onRatingUpdate: onChanged,
    );
  }
}

// lib/screens/profile/widgets/favorite_genres.dart
import 'package:flutter/material.dart';

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
        Text('선호하는 장르', style: Theme.of(context).textTheme.titleMedium),
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

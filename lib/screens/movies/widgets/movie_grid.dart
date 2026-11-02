// lib/screens/movies/widgets/movie_grid.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/movie.dart';
import '../../../widgets/movie_card.dart';

/// 영화 카드를 2열로 배치하는 Grid. 홈과 목록이 같은 모양을 쓴다.
class MovieGrid extends StatelessWidget {
  const MovieGrid({super.key, required this.movies});

  final List<Movie> movies;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: movies.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 20,
        childAspectRatio: 0.62,
      ),
      itemBuilder: (context, index) {
        final movie = movies[index];
        return MovieCard(
          movie: movie,
          onTap: () => context.push('/movies/${movie.id}'),
        );
      },
    );
  }
}

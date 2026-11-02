// lib/screens/movies/widgets/movie_grid.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/tmdb_genre_dto.dart';
import '../../../data/models/tmdb_movie_dto.dart';
import '../../../widgets/movie_card.dart';

/// 영화 카드를 2열로 배치하는 Grid. 홈과 목록이 같은 모양을 쓴다.
class MovieGrid extends StatelessWidget {
  const MovieGrid({
    super.key,
    required this.movies,
    this.genres = const [],
    this.shrinkWrap = false,
    this.physics,
  });

  final List<TmdbMovieDto> movies;

  /// genre_ids 를 이름으로 바꾸기 위한 Genre API 결과.
  final List<TmdbGenreDto> genres;

  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      shrinkWrap: shrinkWrap,
      physics: physics,
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
          genreNames: genres.namesOf(movie.genreIds),
          // 경로에 TMDB id 를 넣고, 이미 받아 둔 DTO 를 extra 로 함께 넘긴다.
          onTap: () => context.push('/movies/${movie.id}', extra: movie),
        );
      },
    );
  }
}

// lib/screens/movies/movie_list_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_movies.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common_app_bar.dart';
import '../../widgets/movie_card.dart';
import 'widgets/genre_filter_sheet.dart';

/// 영화 목록 화면.
///
/// 선택한 장르는 화면 안의 상태가 아니라 Query Parameter 로 들고 있다.
/// 그래서 URL 하나로 같은 목록을 다시 열 수 있다.
class MovieListScreen extends StatelessWidget {
  const MovieListScreen({super.key, this.selectedGenres = const {}});

  final Set<String> selectedGenres;

  /// 선택한 장르를 URL 에 반영한다. 비어 있으면 Parameter 자체를 뺀다.
  void _applyGenres(BuildContext context, Set<String> genres) {
    final location =
        genres.isEmpty ? '/movies' : '/movies?genres=${genres.join(',')}';
    context.go(location);
  }

  Future<void> _openFilterSheet(BuildContext context) async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true, // 시트가 화면 높이를 넘겨 쓸 수 있게 한다.
      builder: (_) => GenreFilterSheet(initialSelection: selectedGenres),
    );

    // 그냥 닫으면 null 이 오므로 그때는 아무것도 바꾸지 않는다.
    if (result == null || !context.mounted) return;
    _applyGenres(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filterByGenres(selectedGenres);

    return Scaffold(
      appBar: CommonAppBar(
        title: '영화',
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: '장르 필터',
            onPressed: () => _openFilterSheet(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _GenreChips(
              selectedGenres: selectedGenres,
              onSelected: (genre) => _applyGenres(
                context,
                genre == allGenresLabel ? const {} : {genre},
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        '해당 장르의 영화가 없어요.',
                        style: AppTextStyles.bodyMedium,
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: filtered.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 20,
                        childAspectRatio: 0.62,
                      ),
                      itemBuilder: (context, index) {
                        final movie = filtered[index];
                        return MovieCard(
                          movie: movie,
                          onTap: () => context.push('/movies/${movie.id}'),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 가로로 스크롤되는 장르 Chip 목록.
class _GenreChips extends StatelessWidget {
  const _GenreChips({required this.selectedGenres, required this.onSelected});

  final Set<String> selectedGenres;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      // 장르가 늘어나도 가로로 스크롤되므로 넘치지 않는다.
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: genres.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final genre = genres[index];
          // 선택이 없으면 전체가 선택된 것으로 본다.
          final isSelected = genre == allGenresLabel
              ? selectedGenres.isEmpty
              : selectedGenres.contains(genre);

          return ChoiceChip(
            label: Text(genre),
            selected: isSelected,
            onSelected: (_) => onSelected(genre),
          );
        },
      ),
    );
  }
}

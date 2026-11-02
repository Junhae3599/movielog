// lib/screens/movies/movie_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/tmdb_genre_dto.dart';
import '../../view_models/movie_list_view_model.dart';
import '../../widgets/common_app_bar.dart';
import 'widgets/genre_filter_sheet.dart';
import 'widgets/movie_grid.dart';
import 'widgets/movie_list_empty.dart';
import 'widgets/movie_list_error.dart';
import 'widgets/movie_list_loading.dart';
import 'widgets/movie_list_retry_dialog.dart';

/// 영화 목록 화면.
///
/// Discover API 결과를 TMDB id 기준 최대 30개로 모아 보여주고,
/// 장르를 고르면 `with_genres` 로 page 1 부터 다시 조회한다.
///
/// 이 Widget 은 상태를 직접 갖지 않는다. API 호출·중복 제거·개수 제한은
/// MovieListViewModel 의 일이고, 여기서는 상태를 구독해 그리기만 한다.
class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key});

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  /// 같은 실패에 Dialog 를 두 번 띄우지 않기 위한 표시.
  bool _isShowingFailureDialog = false;

  Future<void> _openFilterSheet() async {
    final viewModel = context.read<MovieListViewModel>();

    // 요청 중에는 장르를 바꾸지 못하게 한다.
    if (viewModel.isBusy) return;

    final result = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => GenreFilterSheet(
        genres: viewModel.genres,
        initialSelection: viewModel.selectedGenreIds,
      ),
    );

    if (result == null || !mounted) return;
    await viewModel.selectGenres(result);
  }

  /// 최근에 성공한 목록이 있는 상태로 실패했을 때 재시도 Dialog 를 띄운다.
  Future<void> _showFailureDialog(String message) async {
    _isShowingFailureDialog = true;

    final shouldRetry = await showDialog<bool>(
      context: context,
      builder: (_) => MovieListRetryDialog(message: message),
    );

    _isShowingFailureDialog = false;
    if (!mounted) return;

    final viewModel = context.read<MovieListViewModel>();
    if (shouldRetry ?? false) {
      await viewModel.retry();
    } else {
      viewModel.dismissFailure();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '영화',
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: '장르 필터',
            onPressed: _openFilterSheet,
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<MovieListViewModel>(
          builder: (context, viewModel, child) {
            // 목록을 유지한 채 실패를 알려야 하는 경우.
            // build 중에 Dialog 를 띄울 수 없으므로 프레임이 끝난 뒤로 미룬다.
            final failure = viewModel.pendingFailureMessage;
            if (failure != null && !_isShowingFailureDialog) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _showFailureDialog(failure);
              });
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _GenreChips(
                  genres: viewModel.genres,
                  selectedGenreIds: viewModel.selectedGenreIds,
                  // 요청 중에는 Chip 을 눌러도 바뀌지 않게 비활성화한다.
                  enabled: !viewModel.isBusy,
                  onSelected: (genreId) => viewModel.selectGenres(
                    genreId == null ? const [] : [genreId],
                  ),
                ),
                Expanded(child: _body(context, viewModel)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context, MovieListViewModel viewModel) {
    return switch (viewModel.status) {
      MovieListLoadStatus.idle ||
      MovieListLoadStatus.loading =>
        const MovieListLoading(),
      MovieListLoadStatus.error => MovieListError(
          message: viewModel.message,
          onRetry: () => context.read<MovieListViewModel>().retry(),
        ),
      // 새로고침 중에는 기존 목록을 지우지 않는다.
      MovieListLoadStatus.empty => RefreshIndicator(
          onRefresh: () => context.read<MovieListViewModel>().refresh(),
          child: _scrollable(
            MovieListEmpty(
              onReset: viewModel.selectedGenreIds.isEmpty
                  ? null
                  : () => viewModel.selectGenres(const []),
            ),
          ),
        ),
      MovieListLoadStatus.success => RefreshIndicator(
          onRefresh: () => context.read<MovieListViewModel>().refresh(),
          child: MovieGrid(
            movies: viewModel.movies,
            genres: viewModel.genres,
          ),
        ),
    };
  }

  /// 내용이 짧아도 당겨서 새로고침이 되도록 스크롤 가능하게 감싼다.
  Widget _scrollable(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: child,
        ),
      ),
    );
  }
}

/// 가로로 스크롤되는 장르 Chip 목록.
///
/// 첫 Chip 은 "전체"(필터 없음)이고, 선택하면 `with_genres` 를 보내지 않는다.
class _GenreChips extends StatelessWidget {
  const _GenreChips({
    required this.genres,
    required this.selectedGenreIds,
    required this.enabled,
    required this.onSelected,
  });

  final List<TmdbGenreDto> genres;
  final List<int> selectedGenreIds;
  final bool enabled;

  /// null 이면 "전체".
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        // 맨 앞의 "전체" 한 칸을 더한다.
        itemCount: genres.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return ChoiceChip(
              label: const Text('전체'),
              selected: selectedGenreIds.isEmpty,
              onSelected: enabled ? (_) => onSelected(null) : null,
            );
          }

          final genre = genres[index - 1];
          return ChoiceChip(
            label: Text(genre.name),
            selected: selectedGenreIds.contains(genre.id),
            onSelected: enabled ? (_) => onSelected(genre.id) : null,
          );
        },
      ),
    );
  }
}

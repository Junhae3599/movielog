// lib/screens/movies/movie_list_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_movies.dart';
import '../../data/movie.dart';
import '../../data/preferences/genre_preference.dart';
import '../../services/fake_movie_service.dart';
import '../../widgets/common_app_bar.dart';
import 'movie_list_initial_data.dart';
import 'widgets/genre_filter_sheet.dart';
import 'widgets/movie_grid.dart';
import 'widgets/movie_list_empty.dart';
import 'widgets/movie_list_error.dart';
import 'widgets/movie_list_loading.dart';

/// 영화 목록 화면.
///
/// 목록은 FakeMovieService 가 돌려주는 Future 로 받아 Loading·Empty·Error·Success
/// 네 상태를 각각 그린다. 마지막으로 고른 장르는 기기에 저장해 다시 실행해도 남는다.
class MovieListScreen extends StatefulWidget {
  const MovieListScreen({
    super.key,
    this.selectedGenres = const {},
    this.service = const FakeMovieService(),
    this.genrePreference,
  });

  /// URL 의 Query Parameter 로 들어온 장르. 있으면 저장된 값보다 우선한다.
  final Set<String> selectedGenres;

  /// 테스트에서 성공·빈 목록·실패 모드를 바꿔 끼우기 위해 주입받는다.
  final FakeMovieService service;
  final GenrePreference? genrePreference;

  /// 이 시간 안에 응답이 없으면 실패로 본다.
  static const timeout = Duration(seconds: 5);

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  late final GenrePreference _genrePreference =
      widget.genrePreference ?? GenrePreference();

  /// build 안에서 만들면 화면이 다시 그려질 때마다 Loading 이 반복된다.
  /// 그래서 initState 에서 한 번 만들고, 재시도할 때만 새로 만든다.
  late Future<MovieListInitialData> _initialDataFuture;

  /// 현재 걸려 있는 장르. 사용자가 고르기 전에는 저장된 값에서 채워진다.
  Set<String> _selectedGenres = const {};
  bool _didRestoreGenre = false;

  @override
  void initState() {
    super.initState();
    _selectedGenres = widget.selectedGenres;
    _initialDataFuture = _load();
  }

  Future<MovieListInitialData> _load() async {
    // 두 작업이 서로를 기다릴 이유가 없으므로 함께 시작한다.
    final results = await Future.wait([
      widget.service.fetchMovies(),
      _genrePreference.read(),
    ]).timeout(MovieListScreen.timeout);

    return MovieListInitialData(
      movies: results[0] as List<Movie>,
      selectedGenre: results[1] as String,
    );
  }

  /// 재시도. 이때만 새로운 Future 를 만든다.
  void _retry() {
    setState(() {
      _didRestoreGenre = false;
      _initialDataFuture = _load();
    });
  }

  /// 고른 장르를 화면·기기 저장소·URL 에 반영한다.
  Future<void> _applyGenres(Set<String> genres) async {
    setState(() => _selectedGenres = genres);

    // 다음 실행 때 복원할 수 있도록 먼저 저장한다. 여러 개면 첫 번째만 둔다.
    await _genrePreference.save(
      genres.isEmpty ? allGenresLabel : genres.first,
    );

    if (!mounted) return;

    // URL 에 남겨 링크 하나로 같은 목록을 다시 열 수 있게 한다.
    // Router 없이 이 화면만 띄우는 경우(위젯 테스트)에는 건너뛴다.
    final router = GoRouter.maybeOf(context);
    if (router == null) return;

    router.go(
      genres.isEmpty ? '/movies' : '/movies?genres=${genres.join(',')}',
    );
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => GenreFilterSheet(initialSelection: _selectedGenres),
    );

    if (result == null || !mounted) return;
    await _applyGenres(result);
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
        child: FutureBuilder<MovieListInitialData>(
          future: _initialDataFuture,
          builder: (context, snapshot) {
            // 1) Loading
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MovieListLoading();
            }

            // 2) Error — 내부 예외 내용은 화면에 내보내지 않는다.
            if (snapshot.hasError) {
              return MovieListError(
                onRetry: _retry,
                isTimeout: snapshot.error is TimeoutException,
              );
            }

            final data = snapshot.data;
            if (data == null) return MovieListError(onRetry: _retry);

            // 저장된 장르는 처음 한 번만 복원한다. 이후에는 사용자의 선택이 우선이다.
            if (!_didRestoreGenre) {
              _didRestoreGenre = true;
              if (widget.selectedGenres.isEmpty &&
                  data.selectedGenre != allGenresLabel) {
                _selectedGenres = {data.selectedGenre};
              }
            }

            final filtered = _filter(data.movies);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _GenreChips(
                  selectedGenres: _selectedGenres,
                  onSelected: (genre) => _applyGenres(
                    genre == allGenresLabel ? const {} : {genre},
                  ),
                ),
                Expanded(
                  // 3) Empty / 4) Success
                  child: RefreshIndicator(
                    onRefresh: () async => _retry(),
                    child: filtered.isEmpty
                        ? _scrollable(
                            MovieListEmpty(
                              onReset: _selectedGenres.isEmpty
                                  ? null
                                  : () => _applyGenres(const {}),
                            ),
                          )
                        : MovieGrid(movies: filtered),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
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

  List<Movie> _filter(List<Movie> source) {
    if (_selectedGenres.isEmpty) return source;
    return source
        .where((movie) => movie.genres.any(_selectedGenres.contains))
        .toList();
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
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: genres.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final genre = genres[index];
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

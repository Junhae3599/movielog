// lib/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/tmdb_movie_dto.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../view_models/movie_home_view_model.dart';
import '../../widgets/common_app_bar.dart';
import '../movies/widgets/movie_grid.dart';
import '../movies/widgets/movie_list_error.dart';
import '../movies/widgets/movie_list_loading.dart';
import 'widgets/featured_movie_card.dart';

/// 홈 화면. TMDB 인기 영화 중 앞 5개를 보여준다.
///
/// 화면은 상태를 읽어 그리기만 한다. API 호출·JSON 해석·개수 제한 같은
/// 비즈니스 로직은 MovieHomeViewModel 과 TmdbMovieService 에 있다.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: 'MovieLog',
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '검색',
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        // 화면 전체가 아니라 인기 영역만 다시 그리면 되므로 Consumer 를 쓴다.
        child: Consumer<MovieHomeViewModel>(
          builder: (context, viewModel, child) {
            return switch (viewModel.status) {
              MovieHomeLoadStatus.idle ||
              MovieHomeLoadStatus.loading =>
                const MovieListLoading(itemCount: 4),
              MovieHomeLoadStatus.error => MovieListError(
                  message: viewModel.message,
                  onRetry: () =>
                      context.read<MovieHomeViewModel>().loadPopular(),
                ),
              MovieHomeLoadStatus.empty => const _HomeEmpty(),
              MovieHomeLoadStatus.success =>
                _PopularSection(movies: viewModel.popularMovies),
            };
          },
        ),
      ),
    );
  }
}

/// 인기 영화 5개를 추천 카드 1개 + Grid 4개로 나눠 보여준다.
class _PopularSection extends StatelessWidget {
  const _PopularSection({required this.movies});

  final List<TmdbMovieDto> movies;

  @override
  Widget build(BuildContext context) {
    final featured = movies.first;
    // 5개보다 적게 와도 skip 은 있는 만큼만 돌려주므로 범위 오류가 없다.
    final rest = movies.skip(1).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text('오늘은 어떤\n영화를 볼까요?', style: AppTextStyles.headline),
        const SizedBox(height: 20),
        FeaturedMovieCard(
          movie: featured,
          // 경로에 TMDB id 를 넣고, 이미 받아 둔 DTO 를 extra 로 함께 넘긴다.
          onDetailTap: () =>
              context.push('/movies/${featured.id}', extra: featured),
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('인기 영화', style: AppTextStyles.titleMedium),
            GestureDetector(
              // 홈에서 영화 탭으로 넘어간다.
              onTap: () => context.go('/movies'),
              child: Row(
                children: [
                  Text(
                    '전체보기',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.violet,
                      fontSize: 14,
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      size: 20, color: AppColors.violet),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (rest.isNotEmpty)
          MovieGrid(
            movies: rest,
            // ListView 안에 있으므로 자체 스크롤을 끄고 높이를 내용에 맞춘다.
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
          ),
      ],
    );
  }
}

class _HomeEmpty extends StatelessWidget {
  const _HomeEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.movie_filter_outlined,
                size: 56, color: AppColors.gray),
            const SizedBox(height: 16),
            Text(
              '인기 영화가 아직 없어요',
              style: AppTextStyles.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

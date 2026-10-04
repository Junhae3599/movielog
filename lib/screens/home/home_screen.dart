// lib/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_movies.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common_app_bar.dart';
import '../../widgets/movie_card.dart';
import 'widgets/featured_movie_card.dart';

/// 홈 화면. 추천 영화 한 편과 인기 영화 목록을 보여준다.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final featured = movies.first;
    final popular = movies.skip(1).toList();

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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text('오늘은 어떤\n영화를 볼까요?', style: AppTextStyles.headline),
            const SizedBox(height: 20),
            FeaturedMovieCard(
              movie: featured,
              onDetailTap: () => context.push('/movies/${featured.id}'),
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
            GridView.builder(
              // ListView 안에 있으므로 자체 스크롤을 끄고 높이를 내용에 맞춘다.
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: popular.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 20,
                childAspectRatio: 0.62,
              ),
              itemBuilder: (context, index) {
                final movie = popular[index];
                return MovieCard(
                  movie: movie,
                  onTap: () => context.push('/movies/${movie.id}'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

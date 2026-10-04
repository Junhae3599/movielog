// lib/screens/movie_detail/movie_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_movies.dart';
import '../../data/movie.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common_app_bar.dart';
import 'widgets/rating_dialog.dart';

/// 영화 상세 화면.
///
/// Extra 로 영화를 통째로 받지 않고 Path Parameter 의 ID 로 Mock Data 에서
/// 다시 찾는다. 그래야 URL 로 직접 들어와도 화면이 그려진다.
class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.movieId});

  final int? movieId;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool _isFavorite = false;

  /// 내가 남긴 평점. 아직 없으면 null.
  double? _myRating;

  void _toggleFavorite() {
    setState(() => _isFavorite = !_isFavorite);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(_isFavorite ? '즐겨찾기에 추가했어요.' : '즐겨찾기에서 삭제했어요.'),
        ),
      );
  }

  Future<void> _openRatingDialog(Movie movie) async {
    final rating = await showDialog<double>(
      context: context,
      builder: (_) => RatingDialog(
        movieTitle: movie.title,
        initialRating: _myRating,
      ),
    );

    if (rating == null || !mounted) return;

    setState(() => _myRating = rating);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('평점 ${rating.toStringAsFixed(1)}점을 남겼어요.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final movie = findMovieById(widget.movieId);

    // 없는 ID 로 들어온 경우에도 화면이 깨지지 않게 한다.
    if (movie == null) {
      return Scaffold(
        appBar: CommonAppBar(
          title: '영화 상세',
          centerTitle: true,
          onBack: () => context.pop(),
        ),
        body: Center(
          child: Text('영화를 찾을 수 없어요.', style: AppTextStyles.bodyMedium),
        ),
      );
    }

    return Scaffold(
      appBar: CommonAppBar(
        title: 'Cinema Archive',
        centerTitle: true,
        onBack: () => context.pop(),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: '공유',
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Image.asset(movie.posterAsset, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: _MovieInfo(movie: movie, myRating: _myRating),
          ),
          const Divider(height: 40, thickness: 8, color: AppColors.cardFill),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('시놉시스', style: AppTextStyles.titleMedium),
                const SizedBox(height: 12),
                Text(movie.synopsis, style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: _toggleFavorite,
                  icon: Icon(
                    _isFavorite ? Icons.bookmark : Icons.bookmark_border,
                  ),
                  label: const Text('즐겨찾기'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    shape: const StadiumBorder(
                      side: BorderSide(color: AppColors.violet),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openRatingDialog(movie),
                  icon: const Icon(Icons.rate_review_outlined, size: 20),
                  label: const Text('평점 남기기'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 제목, 개봉 정보, 평균 평점, 장르 Chip 을 보여주는 영역.
class _MovieInfo extends StatelessWidget {
  const _MovieInfo({required this.movie, required this.myRating});

  final Movie movie;
  final double? myRating;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(movie.title, style: AppTextStyles.headline),
        const SizedBox(height: 6),
        Text(
          '${movie.year} • ${movie.genreLabel} • ${movie.runtimeMinutes}분',
          style: AppTextStyles.bodyMedium.copyWith(fontSize: 14),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // 평균 평점은 고치는 값이 아니므로 읽기 전용 위젯을 쓴다.
            RatingBarIndicator(
              rating: movie.rating,
              itemCount: 5,
              itemSize: 22,
              itemBuilder: (context, index) =>
                  const Icon(Icons.star, color: Colors.amber),
            ),
            const SizedBox(width: 8),
            Text(
              '${movie.rating} (${movie.ratingCount})',
              style: AppTextStyles.fieldLabel.copyWith(fontSize: 15),
            ),
          ],
        ),
        if (myRating != null) ...[
          const SizedBox(height: 8),
          Text(
            '내 평점 ${myRating!.toStringAsFixed(1)}점',
            style: AppTextStyles.bodyMedium.copyWith(
              fontSize: 14,
              color: AppColors.violet,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: movie.genres.map((g) => Chip(label: Text(g))).toList(),
        ),
      ],
    );
  }
}

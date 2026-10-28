// lib/screens/movie_detail/movie_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/tmdb_movie_dto.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common_app_bar.dart';
import '../../widgets/tmdb_poster_image.dart';
import 'widgets/rating_dialog.dart';

/// 영화 상세 화면.
///
/// 경로에는 **TMDB 가 부여한 영화 id** 가 들어 있고, 목록에서 넘어올 때는
/// 이미 받아 둔 [TmdbMovieDto] 를 extra 로 함께 받아 다시 요청하지 않는다.
///
/// [movieId] 는 6주차에 평점을 저장할 때 자체 백엔드의 `movieId` 로 그대로 전달된다.
/// 목록 배열의 index 를 쓰면 정렬·필터가 바뀔 때 다른 영화를 가리키게 된다.
class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.movieId, this.movie});

  final int? movieId;

  /// 목록에서 넘겨준 영화 정보. URL 로 직접 들어온 경우에는 null 이다.
  final TmdbMovieDto? movie;

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

  Future<void> _openRatingDialog(TmdbMovieDto movie) async {
    final rating = await showDialog<double>(
      context: context,
      builder: (_) => RatingDialog(
        movieTitle: movie.title,
        initialRating: _myRating,
      ),
    );

    if (rating == null || !mounted) return;

    setState(() => _myRating = rating);

    // 6주차에 POST /ratings 로 보낼 값. movieId 는 TMDB id 를 그대로 쓴다.
    debugPrint(
      '[평점 입력] movieId=${movie.id} score=${rating.toStringAsFixed(1)}',
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('평점 ${rating.toStringAsFixed(1)}점을 남겼어요.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;

    // 목록을 거치지 않고 URL 로 바로 들어온 경우에도 화면이 깨지지 않게 한다.
    // (영화 상세 조회 API 연동은 이후 주차 과제다)
    if (movie == null) {
      return Scaffold(
        appBar: CommonAppBar(
          title: '영화 상세',
          centerTitle: true,
          onBack: () => context.pop(),
        ),
        body: Center(
          child: Text('영화 정보를 찾을 수 없어요.', style: AppTextStyles.bodyMedium),
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
            child: TmdbPosterImage(posterPath: movie.posterPath),
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
                // overview 가 비어 있는 영화도 있다.
                Text(
                  movie.overview.isEmpty ? '줄거리 정보가 없어요.' : movie.overview,
                  style: AppTextStyles.bodyMedium,
                ),
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

/// 제목, 개봉 연도, 평균 평점을 보여주는 영역.
class _MovieInfo extends StatelessWidget {
  const _MovieInfo({required this.movie, required this.myRating});

  final TmdbMovieDto movie;
  final double? myRating;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(movie.title, style: AppTextStyles.headline),
        if (movie.releaseYear != null) ...[
          const SizedBox(height: 6),
          Text(
            '${movie.releaseYear}',
            style: AppTextStyles.bodyMedium.copyWith(fontSize: 14),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            // TMDB 의 vote_average 는 10점 만점이므로 5점 별에 맞춰 절반으로 환산한다.
            RatingBarIndicator(
              rating: movie.voteAverage / 2,
              itemCount: 5,
              itemSize: 22,
              itemBuilder: (context, index) =>
                  const Icon(Icons.star, color: Colors.amber),
            ),
            const SizedBox(width: 8),
            Text(
              '${movie.voteAverage.toStringAsFixed(1)} / 10',
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
      ],
    );
  }
}

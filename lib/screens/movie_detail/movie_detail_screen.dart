// lib/screens/movie_detail/movie_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/tmdb_movie_dto.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../view_models/movie_detail_view_model.dart';
import '../../view_models/submit_status.dart';
import '../../widgets/common_app_bar.dart';
import '../../widgets/rating_dialog.dart';
import '../../widgets/tmdb_poster_image.dart';

/// 영화 상세 화면.
///
/// 보여줄 영화와 평점 등록 상태는 [MovieDetailViewModel] 이 들고 있고,
/// 그 ViewModel 은 상위의 `MovieDetailLoader` 가 만든다.
///
/// 이 화면이 하는 쓰기는 **평점 등록 하나**다. 조회·수정·삭제는 마이페이지의
/// "내가 등록한 평점" 화면에서 한다. 등록 결과는 같은 화면의 Snackbar 로 알리고,
/// 실제로 저장됐는지는 그 화면에서 다시 조회해 확인한다.
///
/// 평점 요청의 `movieId` 는 **TMDB 가 부여한 영화 id** 다. 목록 배열의 index 를
/// 쓰면 정렬·필터가 바뀔 때 다른 영화에 평점이 달린다.
class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool _isFavorite = false;

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

  /// 평점 Dialog 를 열고, 저장까지 끝난 뒤에만 Snackbar 를 띄운다.
  Future<void> _openRatingDialog(MovieDetailViewModel viewModel) async {
    final saved = await showDialog<bool>(
      context: context,
      // 저장 중 바깥 탭으로 닫히는 것도 막는다. (PopScope 는 뒤로가기만 막는다)
      barrierDismissible: false,
      builder: (_) => RatingDialog(
        movieTitle: viewModel.movie.title,
        onSubmit: (score, comment) async {
          await viewModel.createRating(score: score, comment: comment);
          // 실패를 예외로 바꿔 Dialog 가 닫히지 않고 다시 시도할 수 있게 한다.
          if (viewModel.submitStatus != SubmitStatus.success) {
            throw StateError(viewModel.submitMessage ?? '저장에 실패했습니다.');
          }
        },
      ),
    );

    // 저장 요청과 Snackbar 는 서로 다른 비동기 경계다. await 뒤에는 화면이
    // 아직 살아 있는지 다시 확인한다.
    if (!mounted || saved != true) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('평점을 등록했습니다. 마이페이지의 "내가 등록한 평점"에서 확인할 수 있습니다.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    // 영화 정보는 바뀌지 않으므로 read 로 한 번만 읽는다.
    final movie = context.read<MovieDetailViewModel>().movie;

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
            child: Consumer<MovieDetailViewModel>(
              builder: (context, viewModel, child) =>
                  _MovieInfo(movie: movie, myScore: viewModel.submittedScore),
            ),
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
                // 가입 전에는 평점을 쓸 회원이 없으므로 버튼을 잠그고 안내한다.
                child: Consumer<MovieDetailViewModel>(
                  builder: (context, viewModel, child) => ElevatedButton.icon(
                    onPressed: viewModel.canSubmit
                        ? () => _openRatingDialog(viewModel)
                        : null,
                    icon: const Icon(Icons.rate_review_outlined, size: 20),
                    label: Text(
                      viewModel.canSubmit ? '평점 남기기' : '회원가입 후 가능',
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      shape: const StadiumBorder(),
                    ),
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
  const _MovieInfo({required this.movie, required this.myScore});

  final TmdbMovieDto movie;

  /// 이번 화면에서 방금 등록한 점수. 아직 등록하지 않았으면 null 이다.
  final int? myScore;

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
        if (myScore != null) ...[
          const SizedBox(height: 8),
          Text(
            '내 평점 $myScore점',
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

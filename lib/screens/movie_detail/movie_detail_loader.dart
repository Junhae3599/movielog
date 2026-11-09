// lib/screens/movie_detail/movie_detail_loader.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/tmdb_movie_dto.dart';
import '../../data/services/rating_api_service.dart';
import '../../data/services/tmdb_movie_service.dart';
import '../../theme/app_text_styles.dart';
import '../../view_models/learning_member_session.dart';
import '../../view_models/movie_detail_view_model.dart';
import '../../widgets/common_app_bar.dart';
import 'movie_detail_screen.dart';

/// 영화 상세 화면의 시작점.
///
/// 상세 화면은 `TmdbMovieDto` 하나를 꼭 필요로 한다. 목록에서 들어오면 이미
/// 받아 둔 DTO 가 `extra` 로 함께 오지만, **URL 로 직접 들어오거나 Deep Link 로
/// 열리면 `extra` 가 없다.** 그때는 경로의 movieId 로 TMDB 에 다시 물어본다.
///
/// 조회가 끝난 뒤에야 [MovieDetailViewModel] 을 만들 수 있으므로, Provider 생성을
/// 이 Widget 이 맡고 화면 자체는 "영화가 확정된 뒤" 만 그린다.
class MovieDetailLoader extends StatefulWidget {
  const MovieDetailLoader({
    super.key,
    required this.movieId,
    this.initialMovie,
  });

  final int movieId;

  /// 목록에서 넘겨준 영화 정보. 있으면 다시 요청하지 않는다.
  final TmdbMovieDto? initialMovie;

  @override
  State<MovieDetailLoader> createState() => _MovieDetailLoaderState();
}

class _MovieDetailLoaderState extends State<MovieDetailLoader> {
  late final Future<TmdbMovieDto> _movieFuture;

  @override
  void initState() {
    super.initState();
    // Future 는 initState 에서 한 번만 만든다. build 안에서 만들면 다시 그릴
    // 때마다 새 요청이 나간다.
    _movieFuture = widget.initialMovie != null
        ? Future.value(widget.initialMovie!)
        : context.read<TmdbMovieService>().fetchMovieDetail(widget.movieId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TmdbMovieDto>(
      future: _movieFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _DetailPlaceholder(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final movie = snapshot.data;
        if (snapshot.hasError || movie == null) {
          return _DetailPlaceholder(
            child: Center(
              child: Text('영화 정보를 찾을 수 없어요.', style: AppTextStyles.bodyMedium),
            ),
          );
        }

        return ChangeNotifierProvider<MovieDetailViewModel>(
          // 평점 경로에 들어갈 memberId 는 root 의 학습용 세션에서 읽는다.
          // 6주차의 고정 memberId 1 을 새 회원의 ID 처럼 쓰지 않는다.
          create: (context) => MovieDetailViewModel(
            context.read<RatingApiService>(),
            context.read<LearningMemberSession>().memberId,
            movie,
          ),
          child: const MovieDetailScreen(),
        );
      },
    );
  }
}

/// 영화가 아직 없을 때(로딩·실패) 쓰는 껍데기 화면.
class _DetailPlaceholder extends StatelessWidget {
  const _DetailPlaceholder({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '영화 상세',
        centerTitle: true,
        onBack: () => context.pop(),
      ),
      body: child,
    );
  }
}

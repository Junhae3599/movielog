// lib/view_models/my_ratings_view_model.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/rating_dto.dart';
import '../data/models/rating_with_movie.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';

/// 6주차에 조회할 회원 id.
///
/// 화면 이름은 "내가 등록한 평점" 이지만 v5 에는 로그인이 없어서 **인증된 내
/// 계정이 아니라 학습용 memberId 1 의 공개 데이터**를 본다. 화면에 입력창을 두지
/// 않고 상수로 관리하며, JWT 주차에 Token 에서 꺼낸 값으로 바뀐다.
const int sampleMemberId = 1;

/// 평점 목록 화면의 네 가지 상태.
enum MyRatingsLoadStatus { idle, loading, success, empty, error }

/// "내가 등록한 평점" 화면 전용 ViewModel.
///
/// 두 서버를 한 화면에서 쓴다. 평점은 MovieLog 자체 백엔드, 제목·포스터는 TMDB.
/// 평점의 주인은 자체 백엔드이므로 **TMDB 조회가 실패해도 평점 목록은 지우지
/// 않는다.**
class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(this._service, this._movieService, this.memberId);

  final RatingApiService _service;
  final TmdbMovieService _movieService;

  final int memberId;

  /// 같은 movieId 를 두 번 조회하지 않기 위한 캐시.
  /// 404(= TMDB 에 없는 영화)는 null 로 캐시해 다시 묻지 않는다.
  final Map<int, TmdbMovieDto?> _movieCache = {};

  List<RatingWithMovie> ratings = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;

  /// Error 화면의 안내 문구, 또는 Success 상태에서 영화 정보만 빠졌을 때의 안내.
  String? message;

  int _requestVersion = 0;
  bool _disposed = false;

  Future<void> load() async {
    final version = ++_requestVersion;
    status = MyRatingsLoadStatus.loading;
    message = null;
    notifyListeners();

    try {
      final rawRatings = await _service.fetchMyRatings(memberId);
      if (_isStale(version)) return;

      final entries = <RatingWithMovie>[];
      var missingMovies = 0;

      for (final rating in rawRatings) {
        if (_isStale(version)) return;

        final movie = await _findMovie(rating);
        if (movie == null) missingMovies++;
        entries.add(RatingWithMovie(rating: rating, movie: movie));
      }
      if (_isStale(version)) return;

      ratings = entries;
      // 빈 배열은 실패가 아니다. Empty 와 Error 를 한 상태로 묶지 않는다.
      status = entries.isEmpty
          ? MyRatingsLoadStatus.empty
          : MyRatingsLoadStatus.success;
      message = missingMovies > 0
          ? '일부 영화 정보를 가져오지 못해 제목·포스터를 대신 표시합니다.'
          : null;
    } on DioException catch (error) {
      if (_isStale(version)) return;

      status = MyRatingsLoadStatus.error;
      message = writeMyRatingsErrorMessage(error);
    }

    if (!_isStale(version)) notifyListeners();
  }

  /// 평점 한 건의 영화 정보를 캐시에서 찾거나 TMDB 에 물어본다.
  ///
  /// TMDB 쪽 실패는 이 화면의 실패가 아니다. 일시적인 네트워크 실패는 캐시하지
  /// 않고 null 로 두어 다음 로딩에서 다시 시도한다.
  Future<TmdbMovieDto?> _findMovie(RatingDto rating) async {
    if (_movieCache.containsKey(rating.movieId)) {
      return _movieCache[rating.movieId];
    }

    try {
      final movie = await _movieService.findMovieById(rating.movieId);
      _movieCache[rating.movieId] = movie;
      return movie;
    } on DioException {
      return null;
    }
  }

  /// 화면이 사라졌거나 새 요청이 시작된 뒤 도착한 응답은 버린다.
  bool _isStale(int version) => _disposed || version != _requestVersion;

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}

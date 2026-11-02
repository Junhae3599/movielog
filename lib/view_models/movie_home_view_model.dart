// lib/view_models/movie_home_view_model.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/services/tmdb_movie_service.dart';

/// 홈 화면의 네 가지 상태.
enum MovieHomeLoadStatus { idle, loading, success, empty, error }

/// 홈 화면(페이지) 전용 ViewModel.
///
/// "인기 영화 중 앞 5개" 는 TMDB 가 정해 준 게 아니라 이 화면의 정책이므로
/// Service 가 아니라 여기서 결정한다.
class MovieHomeViewModel extends ChangeNotifier {
  MovieHomeViewModel(this._service);

  final TmdbMovieService _service;

  /// 홈에 띄울 인기 영화. 첫 페이지 결과의 앞 [popularLimit] 개.
  List<TmdbMovieDto> popularMovies = const [];

  MovieHomeLoadStatus status = MovieHomeLoadStatus.idle;
  String? message;

  static const popularLimit = 5;

  bool _disposed = false;
  bool _isLoading = false;

  Future<void> loadPopular() async {
    // 화면이 다시 그려질 때마다 요청이 중복되지 않게 막는다.
    if (_isLoading) return;
    _isLoading = true;

    status = MovieHomeLoadStatus.loading;
    notifyListeners();

    try {
      final page = await _service.fetchPopular();

      // 결과가 5개보다 적어도 take 는 있는 만큼만 돌려준다.
      // [0]~[4] 를 직접 접근하면 RangeError 가 난다.
      popularMovies = page.results.take(popularLimit).toList();
      status = popularMovies.isEmpty
          ? MovieHomeLoadStatus.empty
          : MovieHomeLoadStatus.success;
      message = null;
    } on DioException catch (error) {
      status = MovieHomeLoadStatus.error;
      message = _messageFor(error);
    } finally {
      _isLoading = false;
    }

    if (!_disposed) notifyListeners();
  }

  /// Token 문제(401)와 네트워크 문제를 구분해 알려준다.
  /// 오류 원문은 로그에만 남기고 화면에는 내보내지 않는다.
  String _messageFor(DioException error) {
    if (error.response?.statusCode == 401) {
      return 'TMDB 인증에 실패했어요. Token 설정을 확인해 주세요.';
    }
    return '인기 영화를 불러오지 못했어요.';
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

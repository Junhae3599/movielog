// lib/view_models/movie_list_view_model.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/tmdb_genre_dto.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/preferences/genre_preference.dart';
import '../data/services/tmdb_movie_service.dart';

/// 영화 목록 화면의 네 가지 상태.
enum MovieListLoadStatus { idle, loading, success, empty, error }

/// 영화 목록 화면(페이지) 전용 ViewModel.
///
/// 화면 정책을 모두 여기서 결정한다.
/// - 최대 [movieLimit] 개까지 모은다
/// - TMDB `id` 기준으로 중복을 제거한다
/// - 선택된 장르를 `with_genres` 로 보내 page 1 부터 다시 조회한다
class MovieListViewModel extends ChangeNotifier {
  MovieListViewModel(this._service, {GenrePreference? genrePreference})
      : _genrePreference = genrePreference ?? GenrePreference();

  final TmdbMovieService _service;

  /// 마지막으로 고른 장르를 기기에 남겨 다시 실행해도 복원되게 한다.
  final GenrePreference _genrePreference;

  /// 한 화면에 모을 영화의 최대 개수.
  static const movieLimit = 30;

  /// 마지막으로 성공한 목록. 실패해도 바로 비우지 않는다.
  List<TmdbMovieDto> movies = const [];

  /// Genre API 로 받아 온 장르. Chip 과 BottomSheet 가 함께 쓴다.
  List<TmdbGenreDto> genres = const [];

  /// 선택된 장르 ID. 비어 있으면 "전체"(`with_genres` 를 보내지 않음).
  List<int> selectedGenreIds = const [];

  MovieListLoadStatus status = MovieListLoadStatus.idle;

  /// Error 화면에 띄울 안내 문구.
  String? message;

  /// 이미 보여줄 목록이 있는 상태에서 요청이 실패했을 때의 안내 문구.
  /// 목록은 그대로 두고 재시도 Dialog 만 띄우기 위해 따로 둔다.
  String? pendingFailureMessage;

  /// 당겨서 새로고침 중. 이때는 기존 목록을 화면에서 지우지 않는다.
  bool isRefreshing = false;

  /// 요청 중에는 장르를 바꾸지 못하게 한다.
  bool get isBusy => status == MovieListLoadStatus.loading || isRefreshing;

  /// 늦게 도착한 이전 요청의 응답을 무시하기 위한 번호.
  /// 장르를 빠르게 바꿀 때 먼저 보낸 요청이 나중에 도착해 다른 장르가 표시되는 것을 막는다.
  int _requestVersion = 0;
  bool _disposed = false;

  /// 결과가 [movieLimit] 개가 되거나 더 이상 페이지가 없을 때까지 요청한다.
  ///
  /// 한 페이지의 개수(TMDB 는 20개)를 코드에 하드코딩하지 않는다.
  /// 장르 결과가 30개보다 적으면 있는 만큼만 돌려주고 오류로 보지 않는다.
  Future<List<TmdbMovieDto>> fetchUpToLimit({List<int>? genreIds}) async {
    // Map 의 key 로 TMDB id 를 써서 페이지 사이에 중복이 생겨도 하나만 남긴다.
    final byId = <int, TmdbMovieDto>{};
    var pageNumber = 1;
    var hasNextPage = true;

    while (byId.length < movieLimit && hasNextPage) {
      final page = await _service.discoverMovies(
        page: pageNumber,
        genreIds: genreIds,
      );

      for (final movie in page.results) {
        byId[movie.id] = movie;
        if (byId.length == movieLimit) break;
      }

      hasNextPage = pageNumber < page.totalPages && page.results.isNotEmpty;
      pageNumber++;
    }

    return byId.values.take(movieLimit).toList();
  }

  /// 화면에 처음 들어왔을 때. 저장된 장르를 복원하고 장르·영화 목록을 불러온다.
  Future<void> loadInitial() async {
    if (selectedGenreIds.isEmpty) {
      selectedGenreIds = await _genrePreference.read();
    }
    await _load(genreIds: selectedGenreIds, loadGenres: true);
  }

  /// 장르 Chip / BottomSheet 선택.
  ///
  /// 빈 목록은 "전체" 를 뜻하고, 그때는 `with_genres` 를 보내지 않는다.
  Future<void> selectGenres(List<int> genreIds) async {
    // 요청 중에는 장르를 바꾸지 않는다. (Required Mission 7)
    if (isBusy) return;

    selectedGenreIds = List.unmodifiable(genreIds);

    // 저장을 기다리는 사이에 다른 장르가 선택되지 않도록 먼저 요청 중으로 바꾼다.
    // (이걸 _load 에만 맡기면 await 하는 동안 isBusy 가 false 라서 두 번째 선택이 끼어든다)
    status = MovieListLoadStatus.loading;
    notifyListeners();

    // 다음 실행 때 복원할 수 있도록 저장한다.
    await _genrePreference.save(selectedGenreIds);
    await _load(genreIds: selectedGenreIds);
  }

  /// 실패한 요청을 마지막 장르 조건으로 처음부터 다시 실행한다.
  Future<void> retry() async {
    pendingFailureMessage = null;
    await _load(genreIds: selectedGenreIds);
  }

  /// 재시도 Dialog 를 닫기만 한다. 목록은 그대로 둔다.
  void dismissFailure() {
    if (pendingFailureMessage == null) return;
    pendingFailureMessage = null;
    notifyListeners();
  }

  /// 당겨서 새로고침. 기존 목록을 유지한 채 현재 장르로 page 1 부터 다시 부른다.
  Future<void> refresh() async {
    // 이미 불러오는 중이면 제스처를 무시한다.
    if (isBusy) return;
    await _load(genreIds: selectedGenreIds, asRefresh: true);
  }

  Future<void> _load({
    required List<int> genreIds,
    bool loadGenres = false,
    bool asRefresh = false,
  }) async {
    final version = ++_requestVersion;

    if (asRefresh) {
      isRefreshing = true;
    } else {
      status = MovieListLoadStatus.loading;
    }
    pendingFailureMessage = null;
    notifyListeners();

    try {
      if (loadGenres || genres.isEmpty) {
        genres = await _service.fetchGenres();
      }
      final discovered = await fetchUpToLimit(
        genreIds: genreIds.isEmpty ? null : genreIds,
      );

      if (_isStale(version)) return;

      movies = discovered;
      status = movies.isEmpty
          ? MovieListLoadStatus.empty
          : MovieListLoadStatus.success;
      message = null;
    } on DioException catch (error) {
      if (_isStale(version)) return;

      final failure = _messageFor(error);
      if (movies.isEmpty) {
        // 보여줄 게 아무것도 없으면 Error 화면으로 간다.
        status = MovieListLoadStatus.error;
        message = failure;
      } else {
        // 최근에 성공한 목록이 있으면 비우지 않고 재시도 Dialog 만 띄운다.
        status = MovieListLoadStatus.success;
        pendingFailureMessage = failure;
      }
    } finally {
      isRefreshing = false;
    }

    if (!_isStale(version)) notifyListeners();
  }

  /// 이미 새 요청이 시작됐거나 화면이 사라졌으면 이 응답은 버린다.
  bool _isStale(int version) => _disposed || version != _requestVersion;

  String _messageFor(DioException error) {
    if (error.response?.statusCode == 401) {
      return 'TMDB 인증에 실패했어요. Token 설정을 확인해 주세요.';
    }
    if (selectedGenreIds.isNotEmpty) {
      return '해당 장르 영화를 불러오지 못했어요.';
    }
    return '영화를 불러오지 못했어요. 다시 시도해 주세요.';
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}

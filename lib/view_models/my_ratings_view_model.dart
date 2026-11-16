// lib/view_models/my_ratings_view_model.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../data/models/rating_dto.dart';
import '../data/models/rating_with_movie.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import 'auth_view_model.dart';
import 'session_rating_store.dart';

/// 평점 목록 화면의 상태.
enum MyRatingsLoadStatus { idle, loading, success, empty, error }

/// 목록을 어디서 가져왔는지.
///
/// 화면이 "이 목록이 전부인가" 를 사용자에게 정직하게 알리기 위해 구분한다.
enum MyRatingsSource {
  /// 공개 유저별 평점 조회로 받은 **전체** 목록. (memberId 를 아는 경우)
  server,

  /// 이번 세션에서 등록한 평점만 모은 목록. 재시작하면 비어 있다.
  session,
}

/// "내가 등록한 평점" 화면 전용 ViewModel.
///
/// 두 서버를 한 화면에서 쓴다. 평점은 MovieLog 백엔드, 제목·포스터는 TMDB.
/// 평점의 주인은 자체 백엔드이므로 **TMDB 조회가 실패해도 평점 목록은 지우지
/// 않는다.** TMDB 에 없는 영화는 `영화 #{movieId}` 로 대신 표시한다.
///
/// 8주차에 목록의 출처가 둘로 갈라졌다.
///
/// - [MyRatingsSource.server] — 이번 세션에 **회원가입까지 한** 회원이라면
///   memberId 를 알고 있으므로 공개 조회로 전체 목록을 읽는다.
/// - [MyRatingsSource.session] — 그 밖의 경우. v7 에는 Token 기반 '내 평점
///   전체 GET' 이 없고 로그인 응답에도 memberId 가 없어서, 이번 세션에 등록한
///   평점만 보여줄 수 있다. 명세에 없는 값을 지어내지 않기로 한 결과다.
///
/// 수정·삭제는 두 경우 모두 v7 보호 API 로 하므로 동작이 같다.
class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(
    this._service,
    this._movieService,
    this._auth,
    this._store, {
    this.memberId,
  });

  final RatingApiService _service;
  final TmdbMovieService _movieService;
  final AuthViewModel _auth;
  final SessionRatingStore _store;

  /// 공개 조회에 쓸 memberId. 모르면 null 이고 그때는 세션 목록을 쓴다.
  final int? memberId;

  /// 같은 movieId 를 두 번 조회하지 않기 위한 캐시.
  /// 404(= TMDB 에 없는 영화)는 null 로 캐시해 다시 묻지 않는다.
  final Map<int, TmdbMovieDto?> _movieCache = {};

  List<RatingWithMovie> ratings = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;

  /// 이번 목록을 어디서 가져왔는지.
  MyRatingsSource source = MyRatingsSource.session;

  /// 영화 정보 일부가 빠졌을 때의 안내.
  String? message;

  /// 쓰기(수정·삭제) 결과를 한 번만 알리는 문구.
  String? actionMessage;

  /// 편집(다중 선택) 모드에서 고른 평점 id. (Challenge)
  final Set<int> selectedRatingIds = {};

  bool isEditMode = false;
  bool isDeletingSelected = false;

  int _requestVersion = 0;
  bool _disposed = false;

  /// 공개 조회로 전체 목록을 읽을 수 있는 상태인지.
  bool get canLoadFullList => memberId != null;

  Future<void> load() async {
    final version = ++_requestVersion;
    status = MyRatingsLoadStatus.loading;
    message = null;
    notifyListeners();

    List<RatingDto> rawRatings;
    final id = memberId;

    if (id != null) {
      try {
        rawRatings = await _service.fetchMyRatings(id);
        if (_isStale(version)) return;
        source = MyRatingsSource.server;
      } on DioException catch (error) {
        if (_isStale(version)) return;

        status = MyRatingsLoadStatus.error;
        message = writeMyRatingsErrorMessage(error);
        notifyListeners();
        return;
      }
    } else {
      // 요청이 없으므로 실패할 일도 없다. 비어 있는 것은 오류가 아니라
      // "이번 세션에 아직 등록한 평점이 없다" 는 정상 상태다.
      rawRatings = _store.ratings;
      source = MyRatingsSource.session;
    }

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
    // 서버에서 사라진 평점이 선택 상태로 남아 있지 않게 한다.
    final liveIds = entries.map((entry) => entry.rating.ratingId).toSet();
    selectedRatingIds.removeWhere((id) => !liveIds.contains(id));
    if (entries.isEmpty) isEditMode = false;

    // 빈 배열은 실패가 아니다. Empty 와 Error 를 한 상태로 묶지 않는다.
    status = entries.isEmpty
        ? MyRatingsLoadStatus.empty
        : MyRatingsLoadStatus.success;
    message = missingMovies > 0
        ? '일부 영화 정보를 가져오지 못해 제목·포스터를 대신 표시합니다.'
        : null;

    notifyListeners();
  }

  /// PATCH 로 평점 한 건을 수정한다.
  ///
  /// v7 의 수정 성공 응답은 **Rating 객체**다. 그래서 목록을 다시 조회하지 않고
  /// 그 객체로 해당 카드만 갈아끼운다. (v6 은 result 가 null 이라 재조회했다)
  ///
  /// 쓰기 자체가 실패하면 [rethrow] 해서 Dialog 가 실패로 처리하고 입력을
  /// 유지한 채 다시 시도할 수 있게 한다.
  Future<void> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    try {
      final updated = await _service.updateRating(
        ratingId: ratingId,
        score: score,
        comment: comment,
      );
      if (_disposed) return;

      _store.upsert(updated);
      _replaceInList(updated);
    } on DioException catch (error) {
      if (_disposed) return;

      await _handleWriteError(error);
      rethrow;
    }
  }

  /// DELETE 로 평점 한 건을 지운다. 성공은 204 가 아니라 200 + result null 이다.
  Future<void> deleteRating(int ratingId) async {
    try {
      await _service.deleteRating(ratingId);
      if (_disposed) return;
    } on DioException catch (error) {
      if (_disposed) return;

      await _handleWriteError(error);
      rethrow;
    }

    _store.remove(ratingId);
    selectedRatingIds.remove(ratingId);
    _removeFromList(ratingId);
  }

  /// 고른 평점을 하나씩 삭제한다. (Challenge)
  ///
  /// 한 번에 보내는 API 가 없으므로 순서대로 호출한다. 일부만 실패해도 성공한
  /// 것은 그대로 지워지므로, **실패한 id 만 선택 상태로 남겨** 다시 시도하게 한다.
  Future<void> deleteSelectedRatings() async {
    if (isDeletingSelected || selectedRatingIds.isEmpty) return;

    isDeletingSelected = true;
    actionMessage = null;
    notifyListeners();

    var failed = 0;
    var expired = false;

    try {
      // 원본 Set 을 순회하면서 remove 하면 ConcurrentModificationError 가 난다.
      for (final ratingId in selectedRatingIds.toList()) {
        if (expired) break;

        try {
          await _service.deleteRating(ratingId);
          selectedRatingIds.remove(ratingId);
          _store.remove(ratingId);
          _removeFromList(ratingId);
        } on DioException catch (error) {
          if (isSessionExpiredCode(apiErrorCode(error))) {
            // 세션이 끝났으면 남은 요청을 더 보내도 전부 401 이다.
            expired = true;
            await _auth.expireSession();
          } else {
            failed++;
          }
        }
      }
    } finally {
      // 예상하지 못한 오류에도 오버레이가 남지 않게 한다.
      isDeletingSelected = false;
      if (!_disposed) notifyListeners();
    }
    if (_disposed || expired) return;

    if (failed > 0) {
      actionMessage = '$failed개 항목을 삭제하지 못했습니다. 선택된 항목을 다시 확인해 주세요.';
    } else {
      isEditMode = false;
    }

    if (ratings.isEmpty) status = MyRatingsLoadStatus.empty;
    notifyListeners();
  }

  /// 쓰기 실패를 화면에 남긴다.
  ///
  /// 401(`AUTH401_2/3/4`)은 안내가 아니라 **세션 정리**가 필요한 상태다.
  /// 403·409 는 안내만 하고 로그인 상태를 유지한다. 인증(401)과 인가(403)를
  /// 같은 처리로 묶으면, 남의 평점을 건드린 것만으로 로그아웃된다.
  Future<void> _handleWriteError(DioException error) async {
    if (isSessionExpiredCode(apiErrorCode(error))) {
      await _auth.expireSession();
      return;
    }

    actionMessage = writeErrorMessage(error);
    notifyListeners();

    // 403·404 는 화면의 목록이 서버 상태와 어긋났다는 신호다.
    if (shouldRefreshAfterRatingError(error) && canLoadFullList) await load();
  }

  /// 목록에서 한 건만 갈아끼운다. 영화 정보는 이미 들고 있던 것을 재사용한다.
  void _replaceInList(RatingDto updated) {
    final index = ratings.indexWhere(
      (entry) => entry.rating.ratingId == updated.ratingId,
    );
    if (index < 0) return;

    final next = [...ratings];
    next[index] = RatingWithMovie(
      rating: updated,
      movie: ratings[index].movie,
    );
    ratings = next;
    notifyListeners();
  }

  void _removeFromList(int ratingId) {
    final next = ratings
        .where((entry) => entry.rating.ratingId != ratingId)
        .toList();
    if (next.length == ratings.length) return;

    ratings = next;
    if (next.isEmpty) {
      status = MyRatingsLoadStatus.empty;
      isEditMode = false;
    }
    notifyListeners();
  }

  /// 쓰기 결과 문구를 한 번만 꺼내 쓴다.
  String? consumeActionMessage() {
    final text = actionMessage;
    actionMessage = null;
    return text;
  }

  /// 편집 모드를 켜고 끈다. 끌 때는 고른 항목도 함께 비운다. (Challenge)
  void setEditMode(bool enabled) {
    if (isDeletingSelected) return;

    isEditMode = enabled;
    if (!enabled) selectedRatingIds.clear();
    notifyListeners();
  }

  void toggleSelection(int ratingId) {
    if (isDeletingSelected) return;

    if (!selectedRatingIds.remove(ratingId)) selectedRatingIds.add(ratingId);
    notifyListeners();
  }

  bool isSelected(int ratingId) => selectedRatingIds.contains(ratingId);

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

// lib/view_models/my_ratings_view_model.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/rating_dto.dart';
import '../data/models/rating_request.dart';
import '../data/models/rating_with_movie.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';

/// 평점 목록 화면의 네 가지 상태.
enum MyRatingsLoadStatus { idle, loading, success, empty, error }

/// "내가 등록한 평점" 화면 전용 ViewModel.
///
/// 두 서버를 한 화면에서 쓴다. 평점은 MovieLog 자체 백엔드, 제목·포스터는 TMDB.
/// 평점의 주인은 자체 백엔드이므로 **TMDB 조회가 실패해도 평점 목록은 지우지
/// 않는다.**
///
/// 7주차부터는 조회뿐 아니라 수정·삭제도 이 화면이 맡는다(등록은 영화 상세).
/// 쓰기 성공과 그 뒤 목록 재조회 실패는 **다른 상태**다. 저장은 끝났는데 GET 만
/// 실패한 경우를 저장 실패로 되돌리면 사용자가 같은 요청을 다시 보내게 된다.
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

  /// "저장은 됐지만 목록을 못 읽었다" 안내. 저장 실패와 구분해서 보여준다.
  String? refreshWarning;

  /// 쓰기(수정·삭제) 실패를 한 번만 알리는 문구. 서버 `message` 를 그대로 담는다.
  ///
  /// 목록 상태를 설명하는 [message] 와 섞지 않는다. 그쪽은 `load()` 가 매번
  /// 비우기 때문에 쓰기 결과를 담아 두면 재조회에 지워진다.
  String? actionMessage;

  /// 편집(다중 선택) 모드에서 고른 평점 id. (Challenge)
  final Set<int> selectedRatingIds = {};

  /// 편집 모드 여부. 켜지면 카드의 수정·삭제 버튼 대신 CheckBox 를 보여준다.
  bool isEditMode = false;

  /// 선택한 여러 건을 삭제하는 중인지. 화면이 이 값으로 로딩 오버레이를 띄운다.
  bool isDeletingSelected = false;

  int _requestVersion = 0;
  bool _disposed = false;

  Future<void> load() async {
    final version = ++_requestVersion;
    status = MyRatingsLoadStatus.loading;
    message = null;
    // 재조회에 성공하면 "저장은 됐지만 못 읽었다" 안내도 사라져야 한다.
    refreshWarning = null;
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
    } on DioException catch (error) {
      if (_isStale(version)) return;

      status = MyRatingsLoadStatus.error;
      message = writeMyRatingsErrorMessage(error);
    }

    if (!_isStale(version)) notifyListeners();
  }

  /// 쓰기 성공 뒤 목록을 서버 상태와 맞춘다.
  ///
  /// `load()` 는 GET 실패를 `status = error` 로 기록한다. 하지만 여기서의 실패는
  /// **저장 실패가 아니라 조회 실패**이므로, Dialog 로 되돌려 보내지 않고 화면에
  /// 조회 재시도 안내만 띄운다.
  Future<void> _refreshAfterWrite() async {
    await load();
    if (_disposed) return;

    if (status == MyRatingsLoadStatus.error) {
      refreshWarning = '저장은 완료됐지만 목록을 불러오지 못했습니다. 조회만 다시 시도해 주세요.';
      notifyListeners();
    } else {
      refreshWarning = null;
    }
  }

  /// PATCH 로 평점 한 건을 수정한 뒤 목록을 다시 읽는다.
  ///
  /// 쓰기 자체가 실패하면 [rethrow] 해서 Dialog 가 실패로 처리하고 입력을
  /// 유지한 채 다시 시도할 수 있게 한다. 그 뒤의 GET 실패는 다시 던지지 않는다.
  Future<void> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    try {
      await _service.updateRating(
        memberId: memberId,
        ratingId: ratingId,
        request: UpdateRatingRequest(score: score, comment: comment),
      );
    } on DioException catch (error) {
      if (_disposed) return;

      await _handleWriteError(error);
      rethrow;
    }

    await _refreshAfterWrite();
  }

  /// DELETE 로 평점 한 건을 지운 뒤 목록을 다시 읽는다.
  Future<void> deleteRating(int ratingId) async {
    try {
      await _service.deleteRating(memberId: memberId, ratingId: ratingId);
    } on DioException catch (error) {
      if (_disposed) return;

      await _handleWriteError(error);
      rethrow;
    }

    selectedRatingIds.remove(ratingId);
    await _refreshAfterWrite();
  }

  /// 쓰기 실패를 화면에 남긴다.
  ///
  /// 403·404 는 화면의 목록이 서버 상태와 어긋났다는 신호이므로 다시 읽는다.
  Future<void> _handleWriteError(DioException error) async {
    actionMessage = writeErrorMessage(error);
    notifyListeners();

    if (shouldRefreshAfterRatingError(error)) await load();
  }

  /// 쓰기 결과 문구를 한 번만 꺼내 쓴다. 꺼낸 뒤에는 비워 두어 화면이 다시
  /// 그려질 때 같은 Snackbar 가 또 뜨지 않게 한다.
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

  /// 고른 평점을 하나씩 삭제한다. (Challenge)
  ///
  /// 요청을 한 번에 보내는 API 가 없으므로 순서대로 호출한다. 일부만 실패해도
  /// 성공한 것은 그대로 지워지므로, **실패한 id 만 선택 상태로 남겨** 다시
  /// 시도할 수 있게 한다.
  Future<void> deleteSelectedRatings() async {
    if (isDeletingSelected || selectedRatingIds.isEmpty) return;

    isDeletingSelected = true;
    actionMessage = null;
    notifyListeners();

    var failed = 0;
    try {
      // 원본 Set 을 순회하면서 remove 하면 ConcurrentModificationError 가 난다.
      for (final ratingId in selectedRatingIds.toList()) {
        try {
          await _service.deleteRating(memberId: memberId, ratingId: ratingId);
          selectedRatingIds.remove(ratingId);
        } on DioException {
          failed++;
          // 실패한 항목은 선택 상태를 유지한다.
        }
      }
    } finally {
      // 예상하지 못한 오류에도 오버레이가 남지 않게 한다.
      isDeletingSelected = false;
      if (!_disposed) notifyListeners();
    }
    if (_disposed) return;

    await _refreshAfterWrite();
    if (_disposed) return;

    if (failed > 0) {
      actionMessage = '$failed개 항목을 삭제하지 못했습니다. 선택된 항목을 다시 확인해 주세요.';
      notifyListeners();
    } else {
      isEditMode = false;
      notifyListeners();
    }
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

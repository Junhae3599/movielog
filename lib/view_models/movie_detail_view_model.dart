// lib/view_models/movie_detail_view_model.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../data/models/rating_dto.dart';
import '../data/models/rating_request.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import 'auth_view_model.dart';
import 'session_rating_store.dart';
import 'submit_status.dart';

/// 영화 상세 화면 전용 ViewModel.
///
/// 이 화면이 하는 쓰기는 **평점 등록 하나**다. 수정·삭제는 "내가 등록한 평점"
/// 화면이 맡는다.
///
/// 8주차에 바뀐 것은 두 가지다.
/// 1. 요청에 memberId 가 사라졌다. 등록 경로가 `/v7/ratings` 이고, 요청자는
///    `Authorization` Header 로만 식별된다. **body 로 옮기지도 않았다.**
/// 2. 등록 성공 응답이 Rating 객체라서, 재조회 없이 그 값으로 화면을 갱신한다.
class MovieDetailViewModel extends ChangeNotifier {
  MovieDetailViewModel(this._ratingService, this._auth, this._store, this.movie);

  final RatingApiService _ratingService;
  final AuthViewModel _auth;
  final SessionRatingStore _store;

  /// 지금 보고 있는 영화. 평점 요청의 `movieId` 는 이 DTO 의 TMDB id 다.
  final TmdbMovieDto movie;

  SubmitStatus submitStatus = SubmitStatus.idle;

  /// 실패 문구. code 별로 정한 우리 문구 또는 서버 `message` 다.
  String? submitMessage;

  /// 방금 등록한 평점. 화면 상단에 "내 평점" 으로 보여준다.
  RatingDto? submittedRating;

  /// 로그인해야 평점을 남길 수 있다.
  ///
  /// Router 가 이미 로그아웃 상태를 `/login` 으로 돌려보내므로 보통은 여기까지
  /// 오지 않는다. 그래도 확인하는 이유는, 화면이 열려 있는 동안 Token 이
  /// 만료돼 `signedOut` 이 될 수 있기 때문이다. 그 찰나에 버튼을 누르면
  /// 요청이 나가 401 을 받는다.
  bool get canSubmit => _auth.isSignedIn;

  bool _disposed = false;

  Future<void> createRating({required int score, String? comment}) async {
    if (!_auth.isSignedIn) {
      submitStatus = SubmitStatus.error;
      submitMessage = '평점을 남기려면 먼저 로그인해 주세요.';
      notifyListeners();
      return;
    }
    // 저장 중 중복 탭을 막는다. (Dialog 버튼도 함께 잠기지만, 화면을 거치지 않는
    // 호출이 생겨도 여기서 한 번 더 걸린다)
    if (submitStatus == SubmitStatus.submitting) return;

    final version = _auth.sessionVersion;
    submitStatus = SubmitStatus.submitting;
    submitMessage = null;
    notifyListeners();

    try {
      final created = await _ratingService.createRating(
        CreateRatingRequest(
          movieId: movie.id,
          score: score,
          comment: comment,
        ),
      );
      // 로그아웃·회원 전환 뒤 늦게 도착한 응답은 화면에 반영하지 않는다.
      if (_disposed || version != _auth.sessionVersion) return;

      submitStatus = SubmitStatus.success;
      submittedRating = created;
      // 마이페이지가 이번 세션의 평점을 보여줄 수 있도록 넘겨 둔다.
      _store.upsert(created);
    } on DioException catch (error) {
      if (_disposed || version != _auth.sessionVersion) return;

      if (isSessionExpiredCode(apiErrorCode(error))) {
        // 만료는 안내가 아니라 세션 정리 대상이다. Router 가 /login 으로 보낸다.
        await _auth.expireSession();
        return;
      }

      submitStatus = SubmitStatus.error;
      submitMessage = writeErrorMessage(error);
    } on StateError catch (error) {
      if (_disposed || version != _auth.sessionVersion) return;

      // 2xx 인데 result 가 없는 응답. 저장됐는지 확신할 수 없으므로 성공으로 보지 않는다.
      submitStatus = SubmitStatus.error;
      submitMessage = error.message;
    }

    // 화면을 떠난 뒤 도착한 응답은 상태를 바꾸지 않는다.
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

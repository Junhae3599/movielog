// lib/view_models/movie_detail_view_model.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/rating_request.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import 'submit_status.dart';

/// 영화 상세 화면 전용 ViewModel.
///
/// 이 화면이 하는 쓰기는 **평점 등록 하나**다. 조회·수정·삭제는 마이페이지의
/// "내가 등록한 평점" 화면이 맡는다. 화면마다 할 일이 다르므로 ViewModel 도
/// 나눠 둔다. (등록 성공 여부는 저장 직후가 아니라 그 화면의 재조회로 확인한다)
class MovieDetailViewModel extends ChangeNotifier {
  MovieDetailViewModel(this._ratingService, this.memberId, this.movie);

  final RatingApiService _ratingService;

  /// 학습용 현재 회원. 로그인 인증이 아니며, 가입 전에는 null 이다.
  final int? memberId;

  /// 지금 보고 있는 영화. 평점 요청의 `movieId` 는 이 DTO 의 TMDB id 다.
  final TmdbMovieDto movie;

  SubmitStatus submitStatus = SubmitStatus.idle;

  /// 실패 문구. 서버가 준 `message` 를 그대로 담는다.
  String? submitMessage;

  /// 방금 등록에 성공한 점수. 화면 상단에 "내 평점" 으로 보여준다.
  int? submittedScore;

  bool get canSubmit => memberId != null;

  bool _disposed = false;

  Future<void> createRating({required int score, String? comment}) async {
    final id = memberId;
    if (id == null) {
      submitStatus = SubmitStatus.error;
      submitMessage = '먼저 회원가입을 완료해 주세요.';
      notifyListeners();
      return;
    }
    // 저장 중 중복 탭을 막는다. (Dialog 버튼도 함께 잠기지만, 화면을 거치지 않는
    // 호출이 생겨도 여기서 한 번 더 걸린다)
    if (submitStatus == SubmitStatus.submitting) return;

    submitStatus = SubmitStatus.submitting;
    submitMessage = null;
    notifyListeners();

    try {
      await _ratingService.createRating(
        memberId: id,
        request: CreateRatingRequest(
          movieId: movie.id,
          score: score,
          comment: comment,
        ),
      );
      if (_disposed) return;

      submitStatus = SubmitStatus.success;
      submittedScore = score;
    } on DioException catch (error) {
      if (_disposed) return;

      submitStatus = SubmitStatus.error;
      submitMessage = writeErrorMessage(error);
    } on StateError catch (error) {
      if (_disposed) return;

      // 201 이 아닌 2xx 응답. 저장됐는지 확신할 수 없으므로 성공으로 보지 않는다.
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

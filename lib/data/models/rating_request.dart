// lib/data/models/rating_request.dart

/// 서버가 받는 평점은 1~5 사이의 **정수**다.
///
/// 별점 Widget 이 이미 정수 단위로만 고르게 막아 두지만, 그 설정이 바뀌거나
/// 다른 화면에서 값을 만들어 보낼 때를 대비한 마지막 안전장치로 남겨 둔다.
/// 조용히 `toInt()` 로 깎지 않고 예외를 던져 **잘못된 값을 보내지 않는다.**
int validateServerScore(double value) {
  if (value < 1 || value > 5 || value != value.roundToDouble()) {
    throw ArgumentError('서버 평점은 1~5 사이 정수여야 합니다.');
  }
  return value.toInt();
}

/// 평점 등록(POST) 요청 body.
///
/// [movieId] 는 **TMDB 가 부여한 영화 id**(`TmdbMovieDto.id`)다. 목록 배열의
/// index 나 임의 번호를 쓰면 정렬·필터가 바뀔 때 다른 영화에 평점이 달린다.
class CreateRatingRequest {
  const CreateRatingRequest({
    required this.movieId,
    required this.score,
    this.comment,
  });

  final int movieId;
  final int score;

  /// 선택 입력. 비어 있으면 key 자체를 보내지 않는다.
  final String? comment;

  /// `if` collection 은 조건을 만족할 때만 Map 에 항목을 넣는다.
  /// 등록에서 comment 는 선택이므로 빈 문자열을 보내는 대신 생략한다.
  Map<String, dynamic> toJson() => {
        'movieId': movieId,
        'score': score,
        if (comment != null && comment!.trim().isNotEmpty)
          'comment': comment!.trim(),
      };
}

/// 평점 수정(PATCH) 요청 body.
///
/// PATCH 지만 서버 계약상 `score` 는 필수이고, `comment` 를 **생략하면 기존
/// 후기가 null 로 덮인다.** 그래서 등록과 달리 comment 를 조건부로 빼지 않고
/// 항상 보낸다. 후기를 지우려는 의도도 `comment: null` 로 명시해서 전달한다.
class UpdateRatingRequest {
  const UpdateRatingRequest({required this.score, this.comment});

  final int score;
  final String? comment;

  Map<String, dynamic> toJson() {
    final trimmed = comment?.trim();
    return {
      'score': score,
      // 빈 문자열은 "후기 없음" 과 같은 뜻이므로 null 로 보낸다.
      'comment': (trimmed == null || trimmed.isEmpty) ? null : trimmed,
    };
  }
}

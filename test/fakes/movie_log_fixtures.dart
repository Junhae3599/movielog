// MovieLog 자체 백엔드(v5) 응답을 흉내내는 테스트 fixture.
import 'package:movielog/data/models/rating_dto.dart';

/// 평점 한 건을 만든다. 지정하지 않은 값은 그럴듯한 기본값으로 채운다.
RatingDto fakeRating(
  int ratingId, {
  int movieId = 550,
  int score = 5,
  String? comment = '최고의 영화!',
  String createdAt = '2026-09-06T12:14:03.000Z',
}) {
  return RatingDto(
    ratingId: ratingId,
    movieId: movieId,
    score: score,
    comment: comment,
    createdAt: DateTime.parse(createdAt),
  );
}

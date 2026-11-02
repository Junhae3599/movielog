// lib/data/models/rating_dto.dart

/// 회원이 남긴 평점 한 건의 응답을 담는 DTO.
///
/// 평점의 주인은 MovieLog 자체 백엔드이고, `movieId` 만 TMDB 쪽 식별자다.
/// 이 클래스는 값만 담고, 자신이 어떻게 그려지는지는 모른다.
class RatingDto {
  const RatingDto({
    required this.ratingId,
    required this.movieId,
    required this.score,
    required this.comment,
    required this.createdAt,
  });

  final int ratingId;

  /// TMDB 영화 식별자. 이 값으로 TMDB 영화 상세를 함께 조회한다.
  final int movieId;

  final int score;

  /// 후기. 응답 명세가 `nullable: true` 이므로 타입에도 그대로 둔다.
  /// 값이 없으면(null) 화면에 후기 줄을 아예 그리지 않는다.
  final String? comment;

  final DateTime createdAt;

  factory RatingDto.fromJson(Map<String, dynamic> json) {
    return RatingDto(
      // score 가 5 처럼 정수로 와도, 5.0 으로 와도 받을 수 있게 num 으로 받는다.
      ratingId: (json['ratingId'] as num).toInt(),
      movieId: (json['movieId'] as num).toInt(),
      score: (json['score'] as num).toInt(),
      comment: json['comment'] as String?,
      // "2026-09-06T12:14:03.000Z" 는 UTC 다. 화면에서 toLocal() 로 바꿔 보여준다.
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

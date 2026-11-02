// MovieLog 자체 백엔드(v5) 응답 DTO 테스트
//
// v5 는 공통 응답 Wrapper 가 없으므로 응답 body 를 그대로 fromJson 에 넘긴다.

import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/data/models/check_result.dart';
import 'package:movielog/data/models/rating_dto.dart';

void main() {
  group('CheckResult', () {
    test('available 값을 그대로 읽는다', () {
      expect(CheckResult.fromJson({'available': true}).available, isTrue);
      expect(CheckResult.fromJson({'available': false}).available, isFalse);
    });
  });

  group('RatingDto', () {
    test('응답 JSON 의 모든 key 를 연결한다', () {
      final rating = RatingDto.fromJson({
        'ratingId': 12,
        'movieId': 550,
        'score': 5,
        'comment': '최고의 영화!',
        'createdAt': '2026-09-06T12:14:03.000Z',
        'updatedAt': '2026-09-06T12:14:03.000Z',
      });

      expect(rating.ratingId, equals(12));
      expect(rating.movieId, equals(550));
      expect(rating.score, equals(5));
      expect(rating.comment, equals('최고의 영화!'));
      // "Z" 가 붙은 값은 UTC 로 해석된다. 화면에서 toLocal() 로 바꿔 보여준다.
      expect(rating.createdAt.isUtc, isTrue);
      expect(rating.createdAt.year, equals(2026));
    });

    test('comment 가 null 이어도 파싱된다', () {
      final rating = RatingDto.fromJson({
        'ratingId': 3,
        'movieId': 13,
        'score': 3,
        'comment': null,
        'createdAt': '2026-11-01T19:00:27.956Z',
      });

      expect(rating.comment, isNull);
      expect(rating.score, equals(3));
    });

    test('score 가 5.0 처럼 소수로 와도 정수로 받는다', () {
      final rating = RatingDto.fromJson({
        'ratingId': 1,
        'movieId': 550,
        'score': 5.0,
        'comment': '좋다',
        'createdAt': '2026-09-06T12:14:03.000Z',
      });

      expect(rating.score, equals(5));
    });
  });
}

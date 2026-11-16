// SessionRatingStore — v7 계약의 한계를 메우는 저장소 (8주차)
//
// 이 저장소가 지켜야 하는 것은 둘이다.
//   1. 수정하면 자리를 지킨다. (목록 맨 앞으로 튀어 오르지 않는다)
//   2. 세션이 바뀌면 비운다. (이전 계정의 평점이 남지 않는다)

import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/view_models/session_rating_store.dart';

import 'fakes/movie_log_fixtures.dart';

void main() {
  test('새 평점은 최신 등록순으로 앞에 쌓인다', () {
    final store = SessionRatingStore()
      ..upsert(fakeRating(1))
      ..upsert(fakeRating(2))
      ..upsert(fakeRating(3));

    // 서버의 유저별 평점 조회(ratingId 내림차순)와 순서를 맞춘다.
    expect(store.ratings.map((r) => r.ratingId), [3, 2, 1]);
  });

  test('같은 ratingId 는 그 자리에서 교체된다', () {
    final store = SessionRatingStore()
      ..upsert(fakeRating(1, score: 5))
      ..upsert(fakeRating(2))
      ..upsert(fakeRating(3));

    store.upsert(fakeRating(1, score: 2, comment: '고친 후기'));

    // 수정 뒤에 맨 앞으로 튀어 오르면 사용자가 보던 위치를 잃는다.
    expect(store.ratings.map((r) => r.ratingId), [3, 2, 1]);
    expect(store.ratings.last.score, 2);
    expect(store.ratings.last.comment, '고친 후기');
  });

  test('remove 는 해당 건만 지운다', () {
    final store = SessionRatingStore()
      ..upsert(fakeRating(1))
      ..upsert(fakeRating(2));

    store.remove(1);
    expect(store.ratings.map((r) => r.ratingId), [2]);

    // 없는 id 를 지우려 해도 조용히 지나간다.
    store.remove(99);
    expect(store.ratings, hasLength(1));
  });

  test('ratings 는 밖에서 고칠 수 없다', () {
    final store = SessionRatingStore()..upsert(fakeRating(1));

    // 화면이 목록을 직접 바꾸면 저장소와 화면이 어긋난다.
    expect(() => store.ratings.add(fakeRating(2)), throwsUnsupportedError);
  });

  group('syncSession', () {
    test('세션 번호가 바뀌면 비운다', () {
      final store = SessionRatingStore()..syncSession(1);
      store.upsert(fakeRating(1));

      // 로그아웃·회원 전환·만료 때마다 sessionVersion 이 올라간다.
      store.syncSession(2);

      expect(store.isEmpty, isTrue);
    });

    test('같은 세션에서는 여러 번 불러도 비우지 않는다', () {
      final store = SessionRatingStore()..syncSession(1);
      store.upsert(fakeRating(1));

      // build 마다 불리므로, 같은 번호로는 아무 일도 하지 않아야 한다.
      store.syncSession(1);
      store.syncSession(1);

      expect(store.ratings, hasLength(1));
    });
  });
}

// MovieDetailViewModel(평점 등록) 테스트

import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/view_models/movie_detail_view_model.dart';
import 'package:movielog/view_models/submit_status.dart';

import 'fakes/fake_rating_api_service.dart';
import 'fakes/tmdb_fixtures.dart';
import 'test_helpers.dart';

MovieDetailViewModel buildViewModel({
  FakeRatingApiService? service,
  int? memberId = testMemberId,
  int movieId = 550,
}) {
  return MovieDetailViewModel(
    service ?? FakeRatingApiService(),
    memberId,
    fakeMovie(movieId),
  );
}

void main() {
  test('등록 요청의 movieId 는 TMDB 영화 id 다', () async {
    final service = FakeRatingApiService();
    await buildViewModel(service: service, movieId: 680)
        .createRating(score: 4, comment: '좋다');

    expect(service.createCalls.single['movieId'], equals(680));
    expect(service.createCalls.single['score'], equals(4));
    expect(service.createCalls.single['comment'], equals('좋다'));
  });

  test('성공하면 방금 등록한 점수를 기억한다', () async {
    final viewModel = buildViewModel();
    await viewModel.createRating(score: 5);

    expect(viewModel.submitStatus, equals(SubmitStatus.success));
    expect(viewModel.submittedScore, equals(5));
    expect(viewModel.submitMessage, isNull);
  });

  test('가입 전에는 요청을 보내지 않고 안내한다', () async {
    final service = FakeRatingApiService();
    final viewModel = buildViewModel(service: service, memberId: null);

    expect(viewModel.canSubmit, isFalse);
    await viewModel.createRating(score: 5);

    expect(service.createCalls, isEmpty);
    expect(viewModel.submitStatus, equals(SubmitStatus.error));
    expect(viewModel.submitMessage, equals('먼저 회원가입을 완료해 주세요.'));
  });

  group('오류를 구분한다', () {
    test('400 은 별점 범위 문구를 그대로 보여준다', () async {
      final viewModel = buildViewModel(
        service: FakeRatingApiService(createMode: FakeWriteMode.badRequest),
      );
      await viewModel.createRating(score: 5);

      expect(viewModel.submitStatus, equals(SubmitStatus.error));
      expect(viewModel.submitMessage, equals('별점은 5점 이하여야 합니다.'));
      expect(viewModel.submittedScore, isNull);
    });

    test('404 는 "유저" 를, 409 는 중복 등록을 가리킨다', () async {
      final notFound = buildViewModel(
        service: FakeRatingApiService(createMode: FakeWriteMode.notFound),
      );
      await notFound.createRating(score: 5);
      // 같은 COMMON404 라도 등록에서는 평점이 아니라 유저가 없다는 뜻이다.
      expect(notFound.submitMessage, equals('존재하지 않는 유저입니다.'));

      final conflict = buildViewModel(
        service: FakeRatingApiService(createMode: FakeWriteMode.conflict),
      );
      await conflict.createRating(score: 5);
      expect(conflict.submitMessage, equals('이미 이 영화에 평점을 남기셨습니다.'));
    });

    test('통신 실패는 기본 문구로 안내한다', () async {
      final viewModel = buildViewModel(
        service: FakeRatingApiService(createMode: FakeWriteMode.failure),
      );
      await viewModel.createRating(score: 5);

      expect(viewModel.submitMessage, contains('요청에 실패했습니다'));
    });
  });

  test('저장 중에는 같은 요청을 다시 보내지 않는다', () async {
    final service = FakeRatingApiService(
      delay: const Duration(milliseconds: 30),
    );
    final viewModel = buildViewModel(service: service);

    final first = viewModel.createRating(score: 5);
    expect(viewModel.submitStatus, equals(SubmitStatus.submitting));

    await viewModel.createRating(score: 4); // 무시된다
    await first;

    expect(service.createCalls, hasLength(1));
  });

  test('화면을 떠난 뒤 도착한 응답은 상태를 바꾸지 않는다', () async {
    final service = FakeRatingApiService(
      delay: const Duration(milliseconds: 30),
    );
    final viewModel = buildViewModel(service: service);

    final pending = viewModel.createRating(score: 5);
    viewModel.dispose();
    await pending;

    // dispose 뒤 notifyListeners 를 부르면 예외가 난다. 상태도 그대로여야 한다.
    expect(viewModel.submitStatus, equals(SubmitStatus.submitting));
    expect(viewModel.submittedScore, isNull);
  });
}

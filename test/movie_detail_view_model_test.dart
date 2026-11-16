// MovieDetailViewModel(평점 등록) 테스트

import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/movie_detail_view_model.dart';
import 'package:movielog/view_models/session_rating_store.dart';
import 'package:movielog/view_models/submit_status.dart';

import 'fakes/fake_auth.dart';
import 'fakes/fake_rating_api_service.dart';
import 'fakes/tmdb_fixtures.dart';
import 'test_helpers.dart';

/// 로그인한 상태의 ViewModel 을 만든다.
///
/// 8주차에는 memberId 가 아니라 **인증 상태**가 등록 가능 여부를 정한다.
Future<MovieDetailViewModel> buildViewModel({
  FakeRatingApiService? service,
  AuthViewModel? auth,
  SessionRatingStore? store,
  int movieId = 550,
}) async {
  return MovieDetailViewModel(
    service ?? FakeRatingApiService(),
    auth ?? await signedInAuthViewModel(),
    store ?? SessionRatingStore(),
    fakeMovie(movieId),
  );
}

/// 로그아웃 상태의 AuthViewModel.
Future<AuthViewModel> signedOutAuth() async {
  final auth = AuthViewModel(
    FakeAuthApiService(),
    FakeMemberApiService(),
    FakeTokenStorage(),
  );
  await auth.restoreSession(); // Token 없음 → signedOut
  return auth;
}

void main() {
  test('등록 요청의 movieId 는 TMDB 영화 id 다', () async {
    final service = FakeRatingApiService();
    final viewModel = await buildViewModel(service: service, movieId: 680);
    await viewModel.createRating(score: 4, comment: '좋다');

    expect(service.createCalls.single['movieId'], equals(680));
    expect(service.createCalls.single['score'], equals(4));
    expect(service.createCalls.single['comment'], equals('좋다'));
  });

  test('등록 body 에 memberId 를 넣지 않는다', () async {
    final service = FakeRatingApiService();
    final viewModel = await buildViewModel(service: service);
    await viewModel.createRating(score: 4, comment: '좋다');

    // v7 은 요청자를 Header 로 식별한다. path 에서 뺀 값을 body 로 옮기지 않는다.
    expect(service.createCalls.single.containsKey('memberId'), isFalse);
  });

  test('성공하면 v7 응답의 Rating 객체를 기억하고 세션 저장소에 넣는다', () async {
    final store = SessionRatingStore();
    final viewModel = await buildViewModel(store: store);
    await viewModel.createRating(score: 5);

    expect(viewModel.submitStatus, equals(SubmitStatus.success));
    expect(viewModel.submittedRating?.score, equals(5));
    expect(viewModel.submitMessage, isNull);
    // 마이페이지가 이번 세션의 평점을 보여줄 수 있어야 한다.
    expect(store.ratings.single.ratingId, viewModel.submittedRating!.ratingId);
  });

  test('로그인 전에는 요청을 보내지 않고 안내한다', () async {
    final service = FakeRatingApiService();
    final viewModel = await buildViewModel(
      service: service,
      auth: await signedOutAuth(),
    );

    expect(viewModel.canSubmit, isFalse);
    await viewModel.createRating(score: 5);

    expect(service.createCalls, isEmpty);
    expect(viewModel.submitStatus, equals(SubmitStatus.error));
    expect(viewModel.submitMessage, equals('평점을 남기려면 먼저 로그인해 주세요.'));
  });

  test('401 은 안내가 아니라 세션 정리로 이어진다', () async {
    final storage = FakeTokenStorage(token: 'saved.token');
    final auth = await signedInAuthViewModel(storage: storage);
    final viewModel = await buildViewModel(
      service: FakeRatingApiService(createMode: FakeWriteMode.expired),
      auth: auth,
    );

    await viewModel.createRating(score: 5);

    expect(auth.status, AuthStatus.signedOut);
    expect(auth.sessionExpired, isTrue);
    expect(storage.deleteCount, 1);
    // 만료는 Dialog 문구가 아니라 로그인 화면의 Snackbar 로 알린다.
    expect(viewModel.submitMessage, isNull);
  });

  group('오류를 구분한다', () {
    test('400 은 별점 범위 문구를 그대로 보여준다', () async {
      final viewModel = await buildViewModel(
        service: FakeRatingApiService(createMode: FakeWriteMode.badRequest),
      );
      await viewModel.createRating(score: 5);

      expect(viewModel.submitStatus, equals(SubmitStatus.error));
      expect(viewModel.submitMessage, equals('별점은 5점 이하여야 합니다.'));
      expect(viewModel.submittedRating, isNull);
    });

    test('MEMBER404_1 과 RATING409_1 을 구분한다', () async {
      final notFound = await buildViewModel(
        service: FakeRatingApiService(createMode: FakeWriteMode.notFound),
      );
      await notFound.createRating(score: 5);
      // v7 은 code 가 도메인별로 갈라져 등록 404 가 회원을 가리킨다는 것이 드러난다.
      expect(notFound.submitMessage, equals('회원 정보를 찾을 수 없어요.'));

      final conflict = await buildViewModel(
        service: FakeRatingApiService(createMode: FakeWriteMode.conflict),
      );
      await conflict.createRating(score: 5);
      expect(
        conflict.submitMessage,
        equals('이미 이 영화에 평점을 남겼어요. 기존 기록을 확인해 주세요.'),
      );
    });

    test('통신 실패는 기본 문구로 안내하고 로그아웃하지 않는다', () async {
      final auth = await signedInAuthViewModel();
      final viewModel = await buildViewModel(
        service: FakeRatingApiService(createMode: FakeWriteMode.failure),
        auth: auth,
      );
      await viewModel.createRating(score: 5);

      expect(viewModel.submitMessage, contains('요청에 실패했습니다'));
      // 네트워크 실패는 401 이 아니다.
      expect(auth.status, AuthStatus.signedIn);
    });
  });

  test('저장 중에는 같은 요청을 다시 보내지 않는다', () async {
    final service = FakeRatingApiService(
      delay: const Duration(milliseconds: 30),
    );
    final viewModel = await buildViewModel(service: service);

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
    final viewModel = await buildViewModel(service: service);

    final pending = viewModel.createRating(score: 5);
    viewModel.dispose();
    await pending;

    // dispose 뒤 notifyListeners 를 부르면 예외가 난다. 상태도 그대로여야 한다.
    expect(viewModel.submitStatus, equals(SubmitStatus.submitting));
    expect(viewModel.submittedRating, isNull);
  });
}

// 내가 등록한 평점 — 수정·삭제 테스트
//
// 저장 성공과 그 뒤 목록 재조회 실패를 구분하는지, 삭제를 확인 없이 보내지
// 않는지, 다중 삭제에서 일부만 실패했을 때 선택이 유지되는지 확인한다.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/router/app_router.dart';
import 'package:movielog/screens/my_ratings/widgets/delete_rating_dialog.dart';
import 'package:movielog/screens/my_ratings/widgets/my_ratings_empty.dart';
import 'package:movielog/screens/my_ratings/widgets/rating_card.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/widgets/movie_log_button.dart';
import 'package:movielog/widgets/rating_dialog.dart';

import 'fakes/fake_rating_api_service.dart';
import 'fakes/fake_tmdb_movie_service.dart';
import 'fakes/movie_log_fixtures.dart';
import 'test_helpers.dart';

MyRatingsViewModel buildViewModel({
  FakeRatingApiService? ratingService,
  FakeTmdbMovieService? movieService,
}) {
  return MyRatingsViewModel(
    ratingService ?? FakeRatingApiService(),
    movieService ?? FakeTmdbMovieService(),
    testMemberId,
  );
}

/// "내가 등록한 평점" 화면을 바로 띄운다.
Future<void> pumpMyRatings(
  WidgetTester tester, {
  FakeRatingApiService? ratingService,
  FakeTmdbMovieService? movieService,
}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  appRouter.go('/my/ratings');
  await tester.pumpWidget(
    withServices(
      movieService ?? FakeTmdbMovieService(),
      ratingApiService: ratingService ?? FakeRatingApiService(),
      memberId: testMemberId,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: appRouter),
    ),
  );
  await tester.pumpAndSettle();
}

/// Dialog 의 취소·확인 버튼. (등장 순서. 저장 중에는 글자가 사라진다)
Finder get cancelButton => find.byType(MovieLogButton).at(0);
Finder get confirmButton => find.byType(MovieLogButton).at(1);

void main() {
  setUp(useInMemoryPreferences);
  tearDown(() => appRouter.go('/'));

  group('MyRatingsViewModel.updateRating', () {
    test('성공하면 목록을 다시 조회한다', () async {
      final service = FakeRatingApiService();
      final viewModel = buildViewModel(ratingService: service);
      await viewModel.load();

      await viewModel.updateRating(ratingId: 1, score: 4, comment: '고친 후기');

      // 저장 뒤 GET 이 한 번 더 나간다.
      expect(service.fetchCalls, hasLength(2));
      expect(viewModel.ratings.first.rating.score, equals(4));
      expect(viewModel.ratings.first.rating.comment, equals('고친 후기'));
      expect(viewModel.refreshWarning, isNull);
    });

    test('comment 를 보내지 않으면 기존 후기가 null 로 덮인다', () async {
      final service = FakeRatingApiService();
      final viewModel = buildViewModel(ratingService: service);
      await viewModel.load();

      await viewModel.updateRating(ratingId: 1, score: 3);

      // 서버 계약을 숨기지 않는다. comment key 는 항상 보내고 값이 null 이다.
      expect(service.updateCalls.single.body.containsKey('comment'), isTrue);
      expect(service.updateCalls.single.body['comment'], isNull);
      expect(viewModel.ratings.first.rating.comment, isNull);
    });

    test('쓰기 실패는 다시 던져 Dialog 가 실패로 처리하게 한다', () async {
      final service = FakeRatingApiService(
        updateMode: FakeWriteMode.badRequest,
      );
      final viewModel = buildViewModel(ratingService: service);
      await viewModel.load();

      await expectLater(
        viewModel.updateRating(ratingId: 1, score: 5),
        throwsA(isA<DioException>()),
      );

      expect(viewModel.actionMessage, equals('별점은 5점 이하여야 합니다.'));
      // 400 은 같은 화면에서 값만 고치면 되므로 재조회하지 않는다.
      expect(service.fetchCalls, hasLength(1));
    });

    test('403 은 목록이 서버와 어긋났다는 신호이므로 다시 조회한다', () async {
      final service = FakeRatingApiService(updateMode: FakeWriteMode.forbidden);
      final viewModel = buildViewModel(ratingService: service);
      await viewModel.load();

      await expectLater(
        viewModel.updateRating(ratingId: 1, score: 5),
        throwsA(isA<DioException>()),
      );

      expect(
        viewModel.actionMessage,
        equals('본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.'),
      );
      expect(service.fetchCalls, hasLength(2));
    });

    test('저장은 됐는데 GET 만 실패하면 저장 실패로 되돌리지 않는다', () async {
      final service = FakeRatingApiService();
      final viewModel = buildViewModel(ratingService: service);
      await viewModel.load();

      // 저장은 성공하고, 그 뒤 재조회만 실패하게 만든다.
      service.mode = FakeRatingMode.failure;
      await viewModel.updateRating(ratingId: 1, score: 4);

      // 예외를 던지지 않았으므로 Dialog 는 저장 성공으로 닫힌다.
      expect(viewModel.status, equals(MyRatingsLoadStatus.error));
      expect(viewModel.refreshWarning, contains('저장은 완료됐지만'));
    });
  });

  group('MyRatingsViewModel.deleteRating', () {
    test('성공하면 목록에서 사라지고 재조회한다', () async {
      final service = FakeRatingApiService();
      final viewModel = buildViewModel(ratingService: service);
      await viewModel.load();

      await viewModel.deleteRating(1);

      expect(service.deleteCalls, equals([1]));
      expect(service.fetchCalls, hasLength(2));
      expect(viewModel.ratings.map((e) => e.rating.ratingId), isNot(contains(1)));
    });

    test('마지막 평점을 지우면 Empty 가 된다', () async {
      final viewModel = buildViewModel(
        ratingService: FakeRatingApiService(ratings: [fakeRating(1)]),
      );
      await viewModel.load();

      await viewModel.deleteRating(1);

      expect(viewModel.status, equals(MyRatingsLoadStatus.empty));
    });

    test('404 는 없는 평점 문구를 보여주고 다시 조회한다', () async {
      final service = FakeRatingApiService(deleteMode: FakeWriteMode.notFound);
      final viewModel = buildViewModel(ratingService: service);
      await viewModel.load();

      await expectLater(
        viewModel.deleteRating(1),
        throwsA(isA<DioException>()),
      );

      expect(viewModel.actionMessage, equals('존재하지 않는 평점입니다.'));
      expect(service.fetchCalls, hasLength(2));
    });
  });

  group('MyRatingsViewModel 다중 삭제 (Challenge)', () {
    test('고른 항목을 하나씩 지우고 편집 모드를 닫는다', () async {
      final service = FakeRatingApiService();
      final viewModel = buildViewModel(ratingService: service);
      await viewModel.load();

      viewModel.setEditMode(true);
      viewModel.toggleSelection(1);
      viewModel.toggleSelection(2);
      expect(viewModel.selectedRatingIds, equals({1, 2}));

      await viewModel.deleteSelectedRatings();

      expect(service.deleteCalls, equals([1, 2]));
      expect(viewModel.selectedRatingIds, isEmpty);
      expect(viewModel.isDeletingSelected, isFalse);
      expect(viewModel.isEditMode, isFalse);
      expect(viewModel.ratings, hasLength(1));
    });

    test('일부만 실패하면 실패한 항목만 선택에 남는다', () async {
      final service = FakeRatingApiService(failingDeleteIds: const {2});
      final viewModel = buildViewModel(ratingService: service);
      await viewModel.load();

      viewModel.setEditMode(true);
      viewModel.toggleSelection(1);
      viewModel.toggleSelection(2);
      await viewModel.deleteSelectedRatings();

      // 성공한 1 은 지워지고, 실패한 2 는 다시 시도할 수 있게 남는다.
      expect(viewModel.selectedRatingIds, equals({2}));
      expect(viewModel.actionMessage, contains('1개 항목을 삭제하지 못했습니다'));
      expect(viewModel.isEditMode, isTrue);
      expect(viewModel.ratings.map((e) => e.rating.ratingId), contains(2));
    });

    test('아무것도 고르지 않으면 요청하지 않는다', () async {
      final service = FakeRatingApiService();
      final viewModel = buildViewModel(ratingService: service);
      await viewModel.load();

      await viewModel.deleteSelectedRatings();

      expect(service.deleteCalls, isEmpty);
    });

    test('편집 모드를 끄면 선택이 비워진다', () async {
      final viewModel = buildViewModel();
      await viewModel.load();

      viewModel.setEditMode(true);
      viewModel.toggleSelection(1);
      viewModel.setEditMode(false);

      expect(viewModel.selectedRatingIds, isEmpty);
    });

    test('서버에서 사라진 평점은 선택에서 빠진다', () async {
      final service = FakeRatingApiService();
      final viewModel = buildViewModel(ratingService: service);
      await viewModel.load();

      viewModel.setEditMode(true);
      viewModel.toggleSelection(1);

      // 다른 기기에서 지워진 상황. 재조회 결과에 1 이 없다.
      service.ratings = [fakeRating(2), fakeRating(3)];
      await viewModel.load();

      expect(viewModel.selectedRatingIds, isEmpty);
    });
  });

  group('화면', () {
    testWidgets('수정 버튼은 기존 별점·코멘트가 채워진 Dialog 를 연다', (tester) async {
      final service = FakeRatingApiService(
        ratings: [fakeRating(1, score: 4, comment: '원래 후기')],
      );
      await pumpMyRatings(tester, ratingService: service);

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(RatingDialog), findsOneWidget);
      // 기존 별점·코멘트가 Dialog 에 채워져 있다.
      final dialog = tester.widget<RatingDialog>(find.byType(RatingDialog));
      expect(dialog.initialScore, equals(4));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        equals('원래 후기'),
      );

      await tester.enterText(find.byType(TextField), '고친 후기');
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(find.byType(RatingDialog), findsNothing);
      expect(service.updateCalls.single.ratingId, equals(1));
      expect(service.updateCalls.single.comment, equals('고친 후기'));
      // 재조회한 목록이 화면에 반영된다.
      expect(find.text('고친 후기'), findsOneWidget);
    });

    testWidgets('comment 가 null 이면 Dialog 가 빈 칸으로 시작한다', (tester) async {
      await pumpMyRatings(
        tester,
        ratingService: FakeRatingApiService(
          ratings: [fakeRating(1, comment: null)],
        ),
      );

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('삭제를 취소하면 요청을 보내지 않는다', (tester) async {
      final service = FakeRatingApiService(
        ratings: [fakeRating(1), fakeRating(2)],
      );
      await pumpMyRatings(tester, ratingService: service);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      expect(find.byType(DeleteRatingDialog), findsOneWidget);
      expect(find.text('삭제한 평점은 복구할 수 없습니다.'), findsOneWidget);

      await tester.tap(find.widgetWithText(MovieLogButton, '취소'));
      await tester.pumpAndSettle();

      expect(find.byType(DeleteRatingDialog), findsNothing);
      expect(service.deleteCalls, isEmpty);
      expect(find.byType(RatingCard), findsNWidgets(2));
    });

    testWidgets('삭제를 확인하면 목록이 갱신되고 마지막이면 Empty 가 된다', (tester) async {
      final service = FakeRatingApiService(ratings: [fakeRating(1)]);
      await pumpMyRatings(tester, ratingService: service);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MovieLogButton, '삭제'));
      await tester.pumpAndSettle();

      expect(service.deleteCalls, equals([1]));
      expect(find.byType(MyRatingsEmpty), findsOneWidget);
    });

    testWidgets('편집 모드에서는 CheckBox 로 여러 건을 골라 지운다', (tester) async {
      final service = FakeRatingApiService();
      await pumpMyRatings(tester, ratingService: service);

      await tester.tap(find.widgetWithText(TextButton, '편집'));
      await tester.pumpAndSettle();

      // 카드마다 수정·삭제 버튼 대신 CheckBox 가 보인다.
      expect(find.byType(Checkbox), findsNWidgets(3));
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      // 고른 게 없으면 삭제 버튼이 잠겨 있다.
      final disabled = tester.widget<MovieLogButton>(
        find.widgetWithText(MovieLogButton, '선택한 0개 삭제'),
      );
      expect(disabled.onPressed, isNull);

      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();
      expect(find.text('2개 선택'), findsOneWidget);

      await tester.tap(find.widgetWithText(MovieLogButton, '선택한 2개 삭제'));
      await tester.pumpAndSettle();

      // 확인 Dialog 는 삭제 여부만 묻고 요청 전에 닫힌다.
      await tester.tap(find.widgetWithText(TextButton, '삭제'));
      await tester.pumpAndSettle();

      expect(service.deleteCalls, hasLength(2));
      expect(find.byType(RatingCard), findsOneWidget);
      // 삭제가 끝나면 편집 모드도 닫힌다.
      expect(find.widgetWithText(TextButton, '편집'), findsOneWidget);
    });

    testWidgets('다중 삭제 중에는 오버레이를 띄우고 이탈을 막는다', (tester) async {
      final service = FakeRatingApiService();
      await pumpMyRatings(tester, ratingService: service);

      // 첫 조회는 바로 끝내고, 삭제 요청만 느리게 만든다.
      service.delay = loadingDelay;

      await tester.tap(find.widgetWithText(TextButton, '편집'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MovieLogButton, '선택한 1개 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '삭제'));
      await tester.pump();

      // Dialog 가 아니라 화면 위 Stack 오버레이다.
      expect(find.byType(ModalBarrier), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.byWidgetPredicate((widget) => widget is PopScope && !widget.canPop),
        findsOneWidget,
      );

      await tester.pumpAndSettle(loadingDelay);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('일부만 실패하면 Snackbar 로 알리고 선택을 남긴다', (tester) async {
      await pumpMyRatings(
        tester,
        ratingService: FakeRatingApiService(failingDeleteIds: const {2}),
      );

      await tester.tap(find.widgetWithText(TextButton, '편집'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MovieLogButton, '선택한 2개 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '삭제'));
      await tester.pumpAndSettle();

      expect(find.textContaining('1개 항목을 삭제하지 못했습니다'), findsOneWidget);
      // 실패한 항목은 선택된 채로 남는다.
      expect(find.text('1개 선택'), findsOneWidget);
    });

    testWidgets('수정 실패는 Dialog 를 닫지 않고 Snackbar 로 서버 문구를 알린다',
        (tester) async {
      await pumpMyRatings(
        tester,
        ratingService: FakeRatingApiService(
          updateMode: FakeWriteMode.forbidden,
          ratings: [fakeRating(1, score: 4, comment: '원래 후기')],
        ),
      );

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '고치려던 후기');
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      // Dialog 는 열린 채로 입력을 유지한다.
      expect(find.byType(RatingDialog), findsOneWidget);
      expect(find.text('저장하지 못했습니다. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
      expect(find.text('고치려던 후기'), findsOneWidget);
      expect(tester.widget<MovieLogButton>(cancelButton).onPressed, isNotNull);
      expect(
        find.text('본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.'),
        findsOneWidget,
      );
    });

    testWidgets('저장 성공 + GET 실패는 다시 조회 안내로 보여준다', (tester) async {
      final service = FakeRatingApiService(
        ratings: [fakeRating(1, score: 4, comment: '원래 후기')],
      );
      await pumpMyRatings(tester, ratingService: service);

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      // 저장까지는 성공하고 그 뒤 재조회만 실패하게 만든다.
      service.mode = FakeRatingMode.failure;
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      // 저장은 끝났으므로 Dialog 는 닫힌다.
      expect(find.byType(RatingDialog), findsNothing);
      expect(find.textContaining('저장은 완료됐지만'), findsOneWidget);

      // 조회만 다시 시도하면 목록이 돌아온다.
      service.mode = FakeRatingMode.success;
      await tester.tap(find.widgetWithText(MovieLogButton, '다시 시도'));
      await tester.pumpAndSettle();

      expect(find.byType(RatingCard), findsOneWidget);
      expect(find.textContaining('저장은 완료됐지만'), findsNothing);
    });
  });
}

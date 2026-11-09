// 내가 등록한 평점 화면 테스트
//
// 마이페이지에서 자식 화면으로 들어가는 흐름과, 목록의
// Loading / Empty / Error / Success 를 확인한다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/router/app_router.dart';
import 'package:movielog/screens/my_ratings/my_ratings_screen.dart';
import 'package:movielog/screens/my_ratings/widgets/my_ratings_empty.dart';
import 'package:movielog/screens/my_ratings/widgets/my_ratings_error.dart';
import 'package:movielog/screens/my_ratings/widgets/my_ratings_loading.dart';
import 'package:movielog/screens/my_ratings/widgets/rating_card.dart';
import 'package:movielog/screens/profile/profile_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/widgets/movie_log_button.dart';

import 'fakes/fake_rating_api_service.dart';
import 'fakes/fake_tmdb_movie_service.dart';
import 'fakes/movie_log_fixtures.dart';
import 'test_helpers.dart';

/// 마이페이지에서 "내가 등록한 평점" 행을 눌러 자식 화면으로 들어간다.
///
/// Route 안의 ViewModel 이 공용 Service 를 context.read 로 찾으므로
/// 앱과 같은 모양으로 Provider 를 함께 올린다.
Future<void> openMyRatings(
  WidgetTester tester, {
  FakeRatingApiService? ratingService,
  FakeTmdbMovieService? movieService,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  appRouter.go('/my');
  await tester.pumpWidget(
    withServices(
      movieService ?? FakeTmdbMovieService(),
      ratingApiService: ratingService ?? FakeRatingApiService(),
      // 7주차 평점 화면은 가입 결과로 받은 memberId 가 있어야 열린다.
      memberId: testMemberId,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: appRouter),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(ProfileScreen), findsOneWidget);

  await tester.tap(find.text('내가 등록한 평점'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // Loading 상태를 보기 위해 전환 애니메이션만 끝내고 멈춘다.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  setUp(useInMemoryPreferences);
  tearDown(() => appRouter.go('/'));

  testWidgets('마이페이지에서 들어가고 뒤로 돌아온다', (tester) async {
    await openMyRatings(tester);

    expect(find.byType(MyRatingsScreen), findsOneWidget);
    // 자식 화면은 root Navigator 위에 열리므로 하단 NavigationBar 가 보이지 않는다.
    expect(find.byType(NavigationBar), findsNothing);
    // 중앙 제목과 뒤로가기 버튼이 있다.
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('Loading 중에는 자리 카드를 보여준다', (tester) async {
    await openMyRatings(
      tester,
      ratingService: FakeRatingApiService(delay: loadingDelay),
      settle: false,
    );

    expect(find.byType(MyRatingsLoading), findsOneWidget);
    expect(find.byType(RatingCard), findsNothing);

    await tester.pumpAndSettle(loadingDelay);
    expect(find.byType(RatingCard), findsWidgets);
  });

  testWidgets('Success — 점수·후기·등록일과 TMDB 제목을 보여준다', (tester) async {
    await openMyRatings(tester);

    expect(find.byType(RatingCard), findsNWidgets(3));
    // 제목은 TMDB 응답에서 온다.
    expect(find.text('영화 550'), findsOneWidget);
    expect(find.text('최고의 영화!'), findsOneWidget);
    expect(find.text('2026.09.06'), findsWidgets);
  });

  testWidgets('comment 가 null 인 평점은 후기 줄을 그리지 않는다', (tester) async {
    await openMyRatings(
      tester,
      ratingService: FakeRatingApiService(
        ratings: [fakeRating(1, movieId: 550, comment: null)],
      ),
    );

    expect(find.byType(RatingCard), findsOneWidget);
    expect(find.text('null'), findsNothing);
    expect(find.text('최고의 영화!'), findsNothing);
  });

  testWidgets('Empty — 평점이 없으면 안내 화면을 보여준다', (tester) async {
    await openMyRatings(
      tester,
      ratingService: FakeRatingApiService(mode: FakeRatingMode.empty),
    );

    expect(find.byType(MyRatingsEmpty), findsOneWidget);
    expect(find.text('아직 등록한 평점이 없어요'), findsOneWidget);
    expect(find.byType(RatingCard), findsNothing);
  });

  testWidgets('Error — 문구와 다시 시도 버튼을 보여주고 재요청한다', (tester) async {
    final service = FakeRatingApiService(mode: FakeRatingMode.notFound);
    await openMyRatings(tester, ratingService: service);

    expect(find.byType(MyRatingsError), findsOneWidget);
    expect(find.text('존재하지 않는 회원입니다.'), findsOneWidget);
    expect(service.fetchCalls, equals([testMemberId]));

    // 다시 시도 버튼은 고정 너비(160)를 쓴다.
    final retry = tester.widget<MovieLogButton>(
      find.widgetWithText(MovieLogButton, '다시 시도'),
    );
    expect(retry.width, equals(160.0));

    service.mode = FakeRatingMode.success;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(service.fetchCalls, equals([testMemberId, testMemberId]));
    expect(find.byType(RatingCard), findsNWidgets(3));
  });

  testWidgets('TMDB 조회가 실패해도 평점은 남고 안내가 붙는다', (tester) async {
    await openMyRatings(
      tester,
      movieService: FakeTmdbMovieService(missingMovieIds: const {550}),
    );

    expect(find.byType(RatingCard), findsNWidgets(3));
    expect(find.textContaining('일부 영화 정보를 가져오지 못해'), findsOneWidget);
    expect(find.text('영화 정보 없음 (movieId 550)'), findsOneWidget);
  });
}

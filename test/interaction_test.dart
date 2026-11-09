// Dialog, BottomSheet, Snackbar 인터랙션 테스트

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/router/app_router.dart';
import 'package:movielog/screens/movie_detail/movie_detail_loader.dart';
import 'package:movielog/screens/movies/widgets/genre_filter_sheet.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/widgets/movie_card.dart';
import 'package:movielog/widgets/movie_log_button.dart';
import 'package:movielog/widgets/movie_rating_input.dart';

import 'fakes/fake_rating_api_service.dart';
import 'fakes/fake_tmdb_movie_service.dart';
import 'test_helpers.dart';

Future<FakeTmdbMovieService> pumpApp(
  WidgetTester tester, {
  required String at,
  FakeTmdbMovieService? service,
  FakeRatingApiService? ratingService,
  int? memberId = testMemberId,
}) async {
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  final fake = service ?? FakeTmdbMovieService();

  appRouter.go(at);
  await tester.pumpWidget(
    withServices(
      fake,
      ratingApiService: ratingService,
      memberId: memberId,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: appRouter),
    ),
  );
  await tester.pumpAndSettle();

  return fake;
}

/// 목록에서 첫 영화의 상세 화면으로 들어간다.
///
/// 상세는 목록에서 받은 영화 DTO 를 extra 로 함께 넘겨받으므로,
/// URL 로 바로 들어가지 않고 목록을 거친다.
Future<FakeRatingApiService> openFirstMovieDetail(
  WidgetTester tester, {
  FakeRatingApiService? ratingService,
  int? memberId = testMemberId,
}) async {
  final fake = ratingService ?? FakeRatingApiService();

  await pumpApp(
    tester,
    at: '/movies',
    ratingService: fake,
    memberId: memberId,
  );
  await tester.tap(find.byType(MovieCard).first);
  await tester.pumpAndSettle();

  return fake;
}

/// Dialog 안 별점 입력의 [index] 번째 별을 눌러 정수 평점을 고른다.
///
/// 화면에는 평균 평점을 보여주는 RatingBarIndicator 의 별도 있으므로
/// MovieRatingInput 안으로 범위를 좁힌다. 7주차부터는 반 점 입력을 막았으므로
/// 별 어디를 눌러도 그 별이 꽉 찬 정수 값이 된다.
Future<void> tapStar(WidgetTester tester, int index) async {
  final star = find.descendant(
    of: find.byType(MovieRatingInput),
    matching: find.byIcon(Icons.star),
  );
  await tester.tap(star.at(index));
  await tester.pumpAndSettle();
}

/// Dialog 의 취소·확인 버튼. (등장 순서)
///
/// 글자로 찾지 않는 이유: 저장 중에는 label Text 대신 인디케이터만 그리므로
/// `widgetWithText` 로는 확인 버튼을 더 찾을 수 없다.
Finder get cancelButton => find.byType(MovieLogButton).at(0);
Finder get confirmButton => find.byType(MovieLogButton).at(1);

MovieLogButton buttonOf(WidgetTester tester, Finder finder) =>
    tester.widget<MovieLogButton>(finder);

void main() {
  setUp(useInMemoryPreferences);
  tearDown(() => appRouter.go('/'));

  testWidgets('즐겨찾기를 누르면 아이콘이 바뀌고 Snackbar 가 뜬다', (tester) async {
    await openFirstMovieDetail(tester);

    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '즐겨찾기'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.text('즐겨찾기에 추가했어요.'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '즐겨찾기'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    expect(find.text('즐겨찾기에서 삭제했어요.'), findsOneWidget);
  });

  testWidgets('평점 남기기를 누르면 코멘트까지 입력하는 Dialog 가 열린다', (tester) async {
    final service = await openFirstMovieDetail(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, '평점 남기기'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(MovieRatingInput), findsOneWidget);
    // 별점 아래에 선택 입력인 코멘트 TextField 가 있다.
    expect(find.text('코멘트를 남겨보세요 (선택)'), findsOneWidget);

    // 별점을 고르기 전에는 코멘트를 써도 확인을 누를 수 없다.
    await tester.enterText(find.byType(TextField), '코멘트만 먼저');
    await tester.pumpAndSettle();
    expect(buttonOf(tester, confirmButton).onPressed, isNull);

    await tapStar(tester, 3);
    expect(buttonOf(tester, confirmButton).onPressed, isNotNull);

    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    // 저장이 끝난 뒤에만 Dialog 가 닫히고 Snackbar 가 뜬다.
    expect(find.byType(Dialog), findsNothing);
    expect(find.textContaining('평점을 등록했습니다.'), findsOneWidget);
    expect(find.text('내 평점 4점'), findsOneWidget);

    // 보낸 body: movieId 는 TMDB id, score 는 정수, comment 는 trim 된 문자열.
    expect(service.createCalls, hasLength(1));
    expect(service.createCalls.single['score'], equals(4));
    expect(service.createCalls.single['comment'], equals('코멘트만 먼저'));
    final loader = tester.widget<MovieDetailLoader>(
      find.byType(MovieDetailLoader),
    );
    expect(
      service.createCalls.single['movieId'],
      equals(loader.initialMovie!.id),
    );
  });

  testWidgets('코멘트를 비우면 comment 를 아예 보내지 않는다', (tester) async {
    final service = await openFirstMovieDetail(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, '평점 남기기'));
    await tester.pumpAndSettle();

    await tapStar(tester, 4);
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(service.createCalls.single.containsKey('comment'), isFalse);
    expect(service.createCalls.single['score'], equals(5));
  });

  testWidgets('별점을 고르는 동안 입력한 코멘트가 사라지지 않는다', (tester) async {
    await openFirstMovieDetail(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, '평점 남기기'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '지워지면 안 된다');
    await tester.pumpAndSettle();

    // Controller 를 build 안에서 새로 만들면 여기서 입력이 초기화된다.
    await tapStar(tester, 2);
    await tapStar(tester, 4);

    expect(find.text('지워지면 안 된다'), findsOneWidget);
  });

  testWidgets('취소를 누르면 요청을 보내지 않는다', (tester) async {
    final service = await openFirstMovieDetail(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, '평점 남기기'));
    await tester.pumpAndSettle();

    await tapStar(tester, 3);
    await tester.tap(cancelButton);
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(service.createCalls, isEmpty);
    expect(find.textContaining('평점을 등록했습니다.'), findsNothing);
  });

  testWidgets('등록 실패는 서버 문구를 보여주고 Dialog 를 닫지 않는다', (tester) async {
    final service = await openFirstMovieDetail(
      tester,
      ratingService: FakeRatingApiService(createMode: FakeWriteMode.conflict),
    );

    await tester.tap(find.widgetWithText(ElevatedButton, '평점 남기기'));
    await tester.pumpAndSettle();

    await tapStar(tester, 3);
    await tester.enterText(find.byType(TextField), '유지되어야 하는 입력');
    await tester.pumpAndSettle();
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    // 실패해도 입력은 남고 다시 시도할 수 있다.
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('저장하지 못했습니다. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
    expect(find.text('유지되어야 하는 입력'), findsOneWidget);
    expect(buttonOf(tester, confirmButton).onPressed, isNotNull);
    expect(service.createCalls, hasLength(1));
  });

  testWidgets('저장 중에는 버튼이 잠기고 중복 탭이 들어가지 않는다', (tester) async {
    final service = await openFirstMovieDetail(
      tester,
      ratingService: FakeRatingApiService(delay: loadingDelay),
    );

    await tester.tap(find.widgetWithText(ElevatedButton, '평점 남기기'));
    await tester.pumpAndSettle();

    await tapStar(tester, 3);
    await tester.tap(confirmButton);
    await tester.pump();

    // 저장 중에는 확인·취소가 모두 잠긴다.
    expect(buttonOf(tester, confirmButton).isLoading, isTrue);
    expect(buttonOf(tester, cancelButton).onPressed, isNull);

    await tester.tap(confirmButton, warnIfMissed: false);
    await tester.pumpAndSettle(loadingDelay);

    expect(service.createCalls, hasLength(1));
  });

  testWidgets('회원가입 전에는 평점 남기기 버튼이 잠긴다', (tester) async {
    await openFirstMovieDetail(tester, memberId: null);

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, '회원가입 후 가능'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('BottomSheet 의 장르는 Genre API 결과로 채워진다', (tester) async {
    await pumpApp(tester, at: '/movies');

    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();

    expect(find.byType(GenreFilterSheet), findsOneWidget);
    // 하드코딩한 장르가 아니라 Fake Genre API 가 돌려준 이름이 보인다.
    expect(find.widgetWithText(CheckboxListTile, '액션'), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, 'SF'), findsOneWidget);
  });

  testWidgets('BottomSheet 에서 장르를 여러 개 고르면 with_genres 로 다시 조회한다',
      (tester) async {
    final service = await pumpApp(tester, at: '/movies');

    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(CheckboxListTile, 'SF'));
    await tester.tap(find.widgetWithText(CheckboxListTile, '애니메이션'));
    await tester.pumpAndSettle();

    // 확인 전에는 아무 요청도 가지 않는다.
    service.discoverCalls.clear();

    await tester.tap(find.widgetWithText(ElevatedButton, '2개 장르 보기'));
    await tester.pumpAndSettle();

    expect(find.byType(GenreFilterSheet), findsNothing);
    expect(service.discoverCalls, isNotEmpty);
    expect(service.discoverCalls.first.page, equals(1));
    expect(service.discoverCalls.first.genreIds, equals([878, 16]));
  });
}

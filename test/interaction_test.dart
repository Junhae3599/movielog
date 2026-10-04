// Dialog, BottomSheet, Snackbar 인터랙션 테스트

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/router/app_router.dart';
import 'package:movielog/screens/movies/widgets/genre_filter_sheet.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/widgets/movie_rating_input.dart';

Future<void> pumpApp(WidgetTester tester, {required String at}) async {
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  appRouter.go(at);
  await tester.pumpWidget(
    MaterialApp.router(theme: AppTheme.light, routerConfig: appRouter),
  );
  await tester.pumpAndSettle();
}

/// Dialog 안 별점 입력의 [index] 번째 별을 눌러 정수 평점을 고른다.
///
/// 화면에는 평균 평점을 보여주는 RatingBarIndicator 의 별도 있으므로
/// MovieRatingInput 안으로 범위를 좁힌다. 반개 단위라 별의 오른쪽을 눌러야
/// 그 별이 꽉 찬 값으로 정해진다.
Future<void> tapStar(WidgetTester tester, int index) async {
  final star = find.descendant(
    of: find.byType(MovieRatingInput),
    matching: find.byIcon(Icons.star),
  );
  final box = tester.getRect(star.at(index));
  await tester.tapAt(Offset(box.right - 2, box.center.dy));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => appRouter.go('/'));

  testWidgets('즐겨찾기를 누르면 아이콘이 바뀌고 Snackbar 가 뜬다', (tester) async {
    await pumpApp(tester, at: '/movies/1');

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

  testWidgets('평점 남기기를 누르면 Dialog 가 열리고 저장하면 Snackbar 가 뜬다', (tester) async {
    await pumpApp(tester, at: '/movies/1');

    await tester.tap(find.widgetWithText(ElevatedButton, '평점 남기기'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(MovieRatingInput), findsOneWidget);

    // 별을 고르기 전에는 저장과 초기화가 모두 잠겨 있다.
    final save = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, '저장'),
    );
    expect(save.onPressed, isNull);

    // 네 번째 별을 눌러 4.0 을 고른다.
    await tapStar(tester, 3);
    expect(find.text('4.0 / 5.0'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.text('평점 4.0점을 남겼어요.'), findsOneWidget);
    expect(find.text('내 평점 4.0점'), findsOneWidget);
  });

  testWidgets('Dialog 의 초기화를 누르면 고른 별점이 지워진다', (tester) async {
    await pumpApp(tester, at: '/movies/1');

    await tester.tap(find.widgetWithText(ElevatedButton, '평점 남기기'));
    await tester.pumpAndSettle();

    await tapStar(tester, 2);
    expect(find.text('3.0 / 5.0'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '초기화'));
    await tester.pumpAndSettle();

    expect(find.text('별을 눌러 선택해주세요'), findsOneWidget);
  });

  testWidgets('BottomSheet 에서 장르를 여러 개 고르고 확인하면 목록에 반영된다', (tester) async {
    await pumpApp(tester, at: '/movies');

    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    expect(find.byType(GenreFilterSheet), findsOneWidget);

    await tester.tap(find.widgetWithText(CheckboxListTile, 'SF'));
    await tester.tap(find.widgetWithText(CheckboxListTile, '애니메이션'));
    await tester.pumpAndSettle();

    // 확인 전에는 URL 이 그대로다.
    expect(appRouter.state.uri.toString(), equals('/movies'));

    await tester.tap(find.widgetWithText(ElevatedButton, '2개 장르 보기'));
    await tester.pumpAndSettle();

    expect(find.byType(GenreFilterSheet), findsNothing);
    final uri = appRouter.state.uri.toString();
    expect(uri, contains('SF'));
    expect(uri, contains('%EC%95%A0%EB%8B%88%EB%A9%94%EC%9D%B4%EC%85%98'));
  });
}

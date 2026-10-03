// MovieLog 화면 스모크 테스트

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/movie_log_app.dart';
import 'package:movielog/screens/profile/profile_screen.dart';
import 'package:movielog/start_screen.dart';
import 'package:movielog/widgets/stat_item.dart';

void main() {
  testWidgets('프로필 화면에 헤더, 통계, 장르가 표시된다', (WidgetTester tester) async {
    await tester.pumpWidget(const MovieLogApp());

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('내 프로필'), findsOneWidget);
    expect(find.text('무비러버'), findsOneWidget);

    // StatItem 을 재사용한 통계 카드 3개
    expect(find.byType(StatItem), findsNWidgets(3));
    expect(find.text('342'), findsOneWidget);

    // 선호 장르 Chip 3개
    expect(find.byType(Chip), findsNWidgets(3));
    expect(find.widgetWithText(TextButton, '프로필 수정'), findsOneWidget);
  });

  testWidgets('시작 화면에 제목, 설명, 버튼이 표시된다', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: StartScreen()),
    );

    expect(find.text('영화의 순간을\n기록하세요'), findsOneWidget);
    expect(
      find.text('보고 싶은 영화부터 나만의 평점까지\n한곳에서 관리해요'),
      findsOneWidget,
    );
    expect(find.widgetWithText(ElevatedButton, '시작하기'), findsOneWidget);
  });
}

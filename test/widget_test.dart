// MovieLog 화면 스모크 테스트

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/screens/profile/profile_screen.dart';
import 'package:movielog/screens/profile/widgets/profile_header.dart';
import 'package:movielog/screens/sign_up/sign_up_screen.dart';
import 'package:movielog/start_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/widgets/stat_item.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

void main() {
  group('프로필 화면', () {
    testWidgets('헤더, 통계, 장르가 표시된다', (tester) async {
      await tester.pumpWidget(_wrap(const ProfileScreen()));

      expect(find.text('내 프로필'), findsOneWidget);
      expect(find.text('무비러버'), findsOneWidget);
      expect(find.byType(StatItem), findsNWidgets(3));
      expect(find.byType(Chip), findsNWidgets(3));
      expect(find.widgetWithText(TextButton, '프로필 수정'), findsOneWidget);
    });

    testWidgets('이미지가 없으면 기본 아이콘을 보여준다', (tester) async {
      await tester.pumpWidget(
        _wrap(const Scaffold(
          body: ProfileHeader(nickname: '무비러버', introduction: '소개'),
        )),
      );

      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });
  });

  group('시작 화면', () {
    testWidgets('제목, 설명, 버튼이 표시된다', (tester) async {
      await tester.pumpWidget(_wrap(const StartScreen()));

      expect(find.text('영화의 순간을\n기록하세요'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, '시작하기'), findsOneWidget);
    });
  });

  group('회원가입 화면', () {
    /// 가입하기 버튼 위젯을 찾는다.
    ElevatedButton submitButton(WidgetTester tester) =>
        tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, '가입하기'),
        );

    testWidgets('입력 전에는 가입 버튼이 비활성화된다', (tester) async {
      await tester.pumpWidget(_wrap(const SignUpScreen()));

      expect(find.text('닉네임'), findsOneWidget);
      expect(find.text('이메일'), findsOneWidget);
      expect(find.text('비밀번호'), findsOneWidget);
      expect(submitButton(tester).onPressed, isNull);
    });

    testWidgets('잘못된 입력에는 한국어 오류 메시지가 표시된다', (tester) async {
      await tester.pumpWidget(_wrap(const SignUpScreen()));

      await tester.enterText(find.byType(TextFormField).at(0), 'a');
      await tester.enterText(find.byType(TextFormField).at(1), 'test@');
      await tester.enterText(find.byType(TextFormField).at(2), '123');
      await tester.pumpAndSettle();

      expect(find.text('닉네임은 2자 이상이어야 합니다.'), findsOneWidget);
      expect(find.text('올바른 이메일 형식이 아닙니다.'), findsOneWidget);
      expect(find.text('비밀번호는 8자 이상이어야 합니다.'), findsOneWidget);
      expect(submitButton(tester).onPressed, isNull);
    });

    testWidgets('약관까지 동의해야 가입 버튼이 활성화된다', (tester) async {
      await tester.pumpWidget(_wrap(const SignUpScreen()));

      await tester.enterText(find.byType(TextFormField).at(0), '무비러버');
      await tester.enterText(find.byType(TextFormField).at(1), 'movie@example.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');
      await tester.pumpAndSettle();

      // 입력은 모두 유효하지만 약관에 동의하기 전까지는 비활성화다.
      expect(submitButton(tester).onPressed, isNull);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(submitButton(tester).onPressed, isNotNull);
    });

    testWidgets('비밀번호 표시 버튼으로 가림 상태가 바뀐다', (tester) async {
      await tester.pumpWidget(_wrap(const SignUpScreen()));

      expect(find.byIcon(Icons.visibility_off), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });
  });
}

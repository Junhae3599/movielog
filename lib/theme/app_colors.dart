// lib/theme/app_colors.dart
import 'package:flutter/material.dart';

/// 디자인(W1-01)에서 추출한 색상값을 한곳에서 관리한다.
/// 화면 코드에서는 Color(0xFF...) 를 직접 쓰지 않고 이 값을 참조한다.
abstract final class AppColors {
  /// 주요 색. AppBar 제목, 버튼 테두리와 글자에 사용한다.
  static const violet = Color(0xFF6750A4);

  /// 강조된 수치와 Chip 글자에 쓰는 진한 보라.
  static const violetDeep = Color(0xFF4F378A);

  /// Chip 배경에 쓰는 연한 보라.
  static const lavender = Color(0xFFE9DDFF);

  /// 화면 배경.
  static const warmWhite = Color(0xFFFAF9F5);

  /// 통계 카드 배경.
  static const cardFill = Color(0xFFF5F3F0);

  static const white = Color(0xFFFFFFFF);

  /// 제목 글자.
  static const black = Color(0xFF1D1B20);

  /// 본문 글자.
  static const bodyGray = Color(0xFF494551);

  /// 보조 라벨 글자.
  static const gray = Color(0xFF9C999E);

  /// 카드와 버튼 테두리.
  static const border = Color(0xFFE7E0EC);

  /// 입력창 배경.
  static const fieldFill = Color(0xFFF4F3EF);

  /// 입력창 테두리.
  static const fieldBorder = Color(0xFFE3E1DE);

  /// 비활성화된 가입 버튼 배경.
  static const violetDisabled = Color(0xFFCCC2DB);

  /// 오류 메시지와 테두리.
  static const error = Color(0xFFB3261E);

  /// 오류 상태의 입력창 배경.
  static const errorFill = Color(0xFFFFDAD7);
}

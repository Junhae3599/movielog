// lib/theme/app_text_styles.dart
import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 반복해서 쓰는 글자 스타일을 모아둔다.
/// 일부 속성만 바꿔야 할 때는 copyWith 를 사용한다.
abstract final class AppTextStyles {
  /// AppBar 제목.
  static const titleLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.black,
  );

  /// 닉네임.
  static const headline = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.black,
  );

  /// 섹션 제목.
  static const titleMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.black,
  );

  /// 본문.
  static const bodyMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.bodyGray,
    height: 1.5,
  );

  /// 통계 카드의 수치.
  static const statValue = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.violetDeep,
  );

  /// 통계 카드의 라벨.
  static const label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.gray,
  );

  /// 입력창 위의 라벨.
  static const fieldLabel = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.black,
  );

  /// 입력창 아래의 오류 메시지.
  static const errorText = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.error,
  );

  /// Chip 글자.
  static const chip = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.violetDeep,
  );
}

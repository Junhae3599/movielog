// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// 앱 전체에 공통으로 적용할 Theme 설정.
abstract final class AppTheme {
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    fontFamily: 'Manrope',
    scaffoldBackgroundColor: AppColors.warmWhite,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.violet,
    ).copyWith(
      primary: AppColors.violet,
      surface: AppColors.warmWhite,
      onSurface: AppColors.black,
      outline: AppColors.border,
    ),
    textTheme: const TextTheme(
      titleLarge: AppTextStyles.titleLarge,
      titleMedium: AppTextStyles.titleMedium,
      bodyMedium: AppTextStyles.bodyMedium,
      labelMedium: AppTextStyles.label,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.warmWhite,
      foregroundColor: AppColors.black,
      centerTitle: false,
      elevation: 0,
      // Material 3 는 스크롤 시 AppBar 색이 변하므로 평평하게 고정한다.
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Android
        statusBarBrightness: Brightness.light, // iOS
        systemNavigationBarColor: AppColors.warmWhite,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.fieldFill,
      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.gray),
      errorStyle: AppTextStyles.errorText,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      // 상태별 테두리. 오류일 때는 배경색까지 바뀌므로 화면에서 따로 처리한다.
      enabledBorder: _fieldBorder(AppColors.fieldBorder),
      focusedBorder: _fieldBorder(AppColors.violet, width: 2),
      errorBorder: _fieldBorder(AppColors.error),
      focusedErrorBorder: _fieldBorder(AppColors.error, width: 2),
      disabledBorder: _fieldBorder(AppColors.fieldBorder),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.violet
            : AppColors.white,
      ),
      checkColor: const WidgetStatePropertyAll(AppColors.white),
      side: const BorderSide(color: AppColors.fieldBorder, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.lavender,
      labelStyle: AppTextStyles.chip,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.violet,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        side: const BorderSide(color: AppColors.violet),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.violet,
        foregroundColor: AppColors.white,
        // onPressed 가 null 이면 자동으로 이 색이 쓰인다.
        disabledBackgroundColor: AppColors.violetDisabled,
        disabledForegroundColor: AppColors.white,
        minimumSize: const Size(double.infinity, 56),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
  );

  /// 입력창 테두리는 색과 두께만 다르므로 한곳에서 만든다.
  static OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

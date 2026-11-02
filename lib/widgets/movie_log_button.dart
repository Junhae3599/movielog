// lib/widgets/movie_log_button.dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 기본 · 통신 중 · 비활성 세 상태를 한곳에서 표현하는 공용 버튼.
///
/// 화면에 종속되지 않고 여러 화면이 그대로 재사용하므로 특정 화면 폴더가 아니라
/// 공용 Widget 위치(`lib/widgets/`)에 둔다.
///
/// 이 Widget 은 **상태를 표시만 하고 스스로 바꾸지 않는다.** 지금 통신 중인지,
/// 누를 수 있는지는 ViewModel 이 정해서 전달한다.
class MovieLogButton extends StatelessWidget {
  const MovieLogButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.width,
    this.height = defaultHeight,
  });

  final String label;

  /// null 이면 조건이 충족되지 않은 비활성 상태다.
  final VoidCallback? onPressed;

  /// true 면 [onPressed] 와 관계없이 항상 비활성이고, 글자 대신 인디케이터만 그린다.
  final bool isLoading;

  /// 가로 공간을 정하는 방식.
  ///
  /// - `null` — 내용(label) 길이에 맞는 Intrinsic 크기. 입력창 옆 보조 버튼처럼
  ///   좁은 자리에 쓴다.
  /// - `double.infinity` — 부모가 허용하는 최대 너비. Form 아래 제출 버튼처럼
  ///   넓은 자리에 쓴다. 너비 제약이 없는 `Row` 안에서는 쓸 수 없다.
  /// - 고정 값 — 주변과 관계없이 항상 같은 크기.
  final double? width;

  /// 세로 높이. 입력창 옆에 나란히 둘 때는 입력창과 같은 높이를 전달한다.
  final double height;

  static const defaultHeight = 56.0;

  bool get _disabled => isLoading || onPressed == null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: _disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          // Theme 의 ElevatedButton 은 minimumSize 가 (infinity, 56) 이다.
          // 그대로 두면 width: null 을 줘도 늘 가로 전체를 차지하고, 너비 제약이
          // 없는 Row 안에서는 오류가 난다. 크기는 이 SizedBox 가 정한다.
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          backgroundColor: AppColors.violet,
          disabledBackgroundColor: AppColors.violetDisabled,
          foregroundColor: AppColors.white,
          disabledForegroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        // 통신 중에는 label 과 인디케이터를 동시에 그리지 않고 하나만 그린다.
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}

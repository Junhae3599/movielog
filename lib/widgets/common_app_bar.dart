// lib/widgets/common_app_bar.dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 화면마다 달라지는 값만 생성자로 받는 공용 AppBar.
/// AppBar 의 공통 구조가 바뀌면 이 파일만 고치면 된다.
class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CommonAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.actions,
    this.centerTitle = false,
    this.titleStyle,
  });

  /// 화면마다 다른 제목.
  final String title;

  /// 왼쪽 뒤로가기 버튼을 눌렀을 때 실행할 이벤트. null 이면 버튼을 숨긴다.
  final VoidCallback? onBack;

  /// 오른쪽에 배치할 Widget 목록.
  final List<Widget>? actions;

  /// 제목 가운데 정렬 여부.
  final bool centerTitle;

  /// 제목 스타일. 전달하지 않으면 보라색 titleLarge 를 사용한다.
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: titleStyle ??
            AppTextStyles.titleLarge.copyWith(color: AppColors.violet),
      ),
      centerTitle: centerTitle,
      leading: onBack == null
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack,
            ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

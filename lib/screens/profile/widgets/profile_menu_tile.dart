// lib/screens/profile/widgets/profile_menu_tile.dart
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// 마이페이지에서 자식 화면으로 들어가는 행.
///
/// 들어갈 수 있다는 것을 오른쪽 꺾쇠로 알린다.
class ProfileMenuTile extends StatelessWidget {
  const ProfileMenuTile({
    super.key,
    required this.title,
    required this.onTap,
  });

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: AppTextStyles.fieldLabel),
      trailing: const Icon(Icons.chevron_right, color: AppColors.gray),
      onTap: onTap,
    );
  }
}

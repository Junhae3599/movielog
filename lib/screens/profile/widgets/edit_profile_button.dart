// lib/screens/profile/widgets/edit_profile_button.dart
import 'package:flutter/material.dart';

/// 프로필 수정 버튼.
///
/// 시안이 배경 없이 테두리만 있는 보조 버튼이라 ElevatedButton 대신
/// TextButton 을 사용한다. 테두리와 색상은 textButtonTheme 에서 가져온다.
class EditProfileButton extends StatelessWidget {
  const EditProfileButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: const Text('프로필 수정'),
    );
  }
}

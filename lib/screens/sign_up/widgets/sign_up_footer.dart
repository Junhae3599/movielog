// lib/screens/sign_up/widgets/sign_up_footer.dart
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// Form 아래의 로그인 안내.
class SignUpFooter extends StatelessWidget {
  const SignUpFooter({super.key, this.onLoginTap});

  final VoidCallback? onLoginTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('이미 계정이 있나요?', style: AppTextStyles.bodyMedium),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onLoginTap,
          child: Text(
            '로그인',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.violet,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

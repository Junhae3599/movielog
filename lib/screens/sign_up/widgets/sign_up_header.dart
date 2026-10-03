// lib/screens/sign_up/widgets/sign_up_header.dart
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// Form 위쪽의 인사말.
///
/// 넓은 화면에서는 AppBar 가 사라지므로 제목을 여기서 대신 보여준다.
class SignUpHeader extends StatelessWidget {
  const SignUpHeader({super.key, required this.showTitle});

  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showTitle) ...[
          Text(
            '회원가입',
            style: AppTextStyles.headline.copyWith(color: AppColors.violet),
          ),
          const SizedBox(height: 8),
          Text(
            'MovieLog에 오신 것을 환영합니다!',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium,
          ),
        ] else
          Text(
            '환영합니다!\n간단한 정보만 입력하고 시작해보세요.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium,
          ),
      ],
    );
  }
}

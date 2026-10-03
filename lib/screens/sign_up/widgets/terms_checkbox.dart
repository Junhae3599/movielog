// lib/screens/sign_up/widgets/terms_checkbox.dart
import 'package:flutter/material.dart';

import '../../../theme/app_text_styles.dart';

/// 필수 약관 동의 Checkbox.
class TermsCheckbox extends StatelessWidget {
  const TermsCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: (checked) => onChanged(checked ?? false),
        ),
        const SizedBox(width: 4),
        // 글자를 눌러도 체크가 바뀌도록 감싼다.
        Flexible(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            child: Text(
              '필수 약관에 동의합니다',
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }
}

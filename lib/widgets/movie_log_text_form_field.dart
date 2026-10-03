// lib/widgets/movie_log_text_form_field.dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 라벨이 위에 붙고 상태에 따라 배경·테두리·오른쪽 아이콘이 바뀌는 공통 입력창.
///
/// 상태별 스타일은 inputDecorationTheme 에 두었고, 오류일 때 배경색까지
/// 바꾸는 부분만 여기서 처리한다.
class MovieLogTextFormField extends StatelessWidget {
  const MovieLogTextFormField({
    super.key,
    required this.label,
    required this.hintText,
    required this.controller,
    required this.validator,
    this.focusNode,
    this.nextFocusNode,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final String? Function(String?) validator;
  final FocusNode? focusNode;

  /// 키보드의 다음 버튼을 눌렀을 때 포커스를 넘길 대상.
  final FocusNode? nextFocusNode;

  final TextInputType? keyboardType;
  final bool obscureText;

  /// 비밀번호 표시·숨김 버튼처럼 입력창마다 다른 오른쪽 위젯.
  final Widget? suffixIcon;

  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    // 현재 입력값이 규칙을 통과하는지. 아이콘과 배경색을 고르는 데 쓴다.
    final errorText = validator(controller.text);
    final hasError = errorText != null;
    final isFilled = controller.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.fieldLabel),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          // 입력하는 동안 바로 오류를 보여준다. 기본값(disabled)이면
          // validate() 를 직접 부르기 전까지 메시지가 뜨지 않는다.
          autovalidateMode: AutovalidateMode.onUserInteraction,
          textInputAction:
              nextFocusNode == null ? TextInputAction.done : TextInputAction.next,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.black),
          decoration: InputDecoration(
            hintText: hintText,
            // 오류일 때만 배경을 붉게 바꾼다.
            fillColor: isFilled && hasError ? AppColors.errorFill : null,
            suffixIcon: suffixIcon ?? _buildStatusIcon(isFilled, hasError),
          ),
          onChanged: onChanged,
          onFieldSubmitted: (_) {
            if (nextFocusNode != null) {
              nextFocusNode!.requestFocus();
            } else {
              onSubmitted?.call();
            }
          },
        ),
      ],
    );
  }

  /// 입력이 있을 때만 통과·오류 아이콘을 보여준다.
  Widget? _buildStatusIcon(bool isFilled, bool hasError) {
    if (!isFilled) return null;

    return Icon(
      hasError ? Icons.error_outline : Icons.check_circle,
      color: hasError ? AppColors.error : AppColors.violet,
    );
  }
}

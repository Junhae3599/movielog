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
    this.errorText,
    this.trailing,
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

  /// 형식 검증과 별개로 서버가 알려준 오류. (예: 이미 사용 중인 닉네임)
  ///
  /// [validator] 는 형식만 보기 때문에 중복 여부는 알지 못한다. 이 값이 있으면
  /// 형식이 맞아도 입력창은 계속 에러 상태로 보여야 한다.
  final String? errorText;

  /// 입력창 오른쪽에 나란히 놓을 Widget. (예: 중복 확인 버튼)
  ///
  /// 입력창 **안**이 아니라 바깥 오른쪽에 8px 간격을 두고 형제로 배치된다.
  /// 입력창 내부 아이콘은 [suffixIcon] 이다.
  final Widget? trailing;

  final FocusNode? focusNode;

  /// 키보드의 다음 버튼을 눌렀을 때 포커스를 넘길 대상.
  final FocusNode? nextFocusNode;

  final TextInputType? keyboardType;
  final bool obscureText;

  /// 비밀번호 표시·숨김 버튼처럼 입력창마다 다른 오른쪽 위젯.
  final Widget? suffixIcon;

  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  /// 입력창 한 줄의 높이.
  ///
  /// 오른쪽에 나란히 두는 버튼이 같은 높이를 쓸 수 있도록 공개한다.
  /// (contentPadding 18*2 + bodyMedium 한 줄 24)
  static const inputHeight = 60.0;

  @override
  Widget build(BuildContext context) {
    // 현재 입력값이 규칙을 통과하는지. 아이콘과 배경색을 고르는 데 쓴다.
    final hasError = validator(controller.text) != null || errorText != null;
    final isFilled = controller.text.isNotEmpty;

    final field = TextFormField(
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
        // errorText 가 null 이면 validator 의 결과가 그대로 쓰인다.
        // 값이 있으면 그것이 우선해서 표시된다.
        errorText: errorText,
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
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.fieldLabel),
        const SizedBox(height: 8),
        if (trailing == null)
          field
        else
          Row(
            // 오류 문구가 붙어 입력창이 길어져도 버튼은 첫 줄 높이에 머문다.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 안에서는 입력창의 너비를 Expanded 가 먼저 정해 준다.
              Expanded(child: field),
              const SizedBox(width: 8),
              trailing!,
            ],
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

// lib/widgets/loading_overlay.dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 화면 위에 어두운 막과 인디케이터만 덮는 오버레이.
///
/// Dialog 가 아니라 **그 화면 위에 올린 Stack** 이다. 여러 건을 순서대로
/// 처리하는 동안(다중 삭제) 확인 Dialog 는 이미 닫혀 있고, 화면만 잠겨야 한다.
///
/// [ModalBarrier] 가 아래 Widget 의 탭을 모두 삼키므로 진행 중에는 목록을
/// 건드릴 수 없다. 흰색 카드나 로딩 문구는 두지 않는다.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  final bool isLoading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading) ...[
          const ModalBarrier(dismissible: false, color: Colors.black45),
          const Center(
            child: CircularProgressIndicator(color: AppColors.white),
          ),
        ],
      ],
    );
  }
}

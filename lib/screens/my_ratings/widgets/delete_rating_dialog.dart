// lib/screens/my_ratings/widgets/delete_rating_dialog.dart
import 'package:flutter/material.dart';

import '../../../theme/app_text_styles.dart';
import '../../../widgets/movie_log_button.dart';

/// 평점 한 건을 지우기 전에 확인하는 Dialog.
///
/// 삭제는 되돌릴 수 없으므로 확인 없이 바로 실행하지 않는다. "취소" 를 누르면
/// [onConfirm] 을 호출하지 않으므로 DELETE 요청도 가지 않는다.
///
/// 단일 삭제는 **요청이 끝날 때까지 이 Dialog 를 유지한다.** 삭제 중 상태를
/// 여기서 보여주고 이탈을 막기 때문이다. (여러 건을 지우는 Challenge 흐름은
/// 반대로 Dialog 를 먼저 닫고 화면 위 오버레이로 진행을 보여준다)
///
/// 돌려주는 값은 실제로 삭제까지 마쳤을 때만 `true` 다.
class DeleteRatingDialog extends StatefulWidget {
  const DeleteRatingDialog({super.key, required this.onConfirm});

  final Future<void> Function() onConfirm;

  @override
  State<DeleteRatingDialog> createState() => _DeleteRatingDialogState();
}

class _DeleteRatingDialogState extends State<DeleteRatingDialog> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDeleting,
      child: AlertDialog(
        title: const Text('평점을 삭제할까요?'),
        content: Text('삭제한 평점은 복구할 수 없습니다.', style: AppTextStyles.bodyMedium),
        actions: [
          MovieLogButton(
            label: '취소',
            onPressed:
                _isDeleting ? null : () => Navigator.of(context).pop(false),
          ),
          MovieLogButton(
            label: '삭제',
            isLoading: _isDeleting,
            onPressed: _isDeleting ? null : _onConfirm,
          ),
        ],
      ),
    );
  }

  Future<void> _onConfirm() async {
    setState(() => _isDeleting = true);

    try {
      await widget.onConfirm();
      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      // 실패하면 Dialog 를 닫지 않고 다시 시도할 수 있게 둔다.
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('삭제하지 못했습니다. 잠시 후 다시 시도해 주세요.')),
      );
    }
  }
}

// lib/screens/movies/widgets/movie_list_retry_dialog.dart
import 'package:flutter/material.dart';

import '../../../theme/app_text_styles.dart';

/// 이미 보여줄 목록이 있는 상태에서 요청이 실패했을 때 띄우는 Dialog.
///
/// 목록을 화면에서 비우지 않고, 재시도와 취소만 묻는다.
/// 재시도를 고르면 true, 취소하거나 그냥 닫으면 null 을 돌려준다.
class MovieListRetryDialog extends StatelessWidget {
  const MovieListRetryDialog({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('목록을 불러오지 못했어요', style: AppTextStyles.titleMedium),
      content: Text(message, style: AppTextStyles.bodyMedium),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('다시 시도'),
        ),
      ],
    );
  }
}

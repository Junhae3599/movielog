// lib/widgets/rating_dialog.dart
import 'package:flutter/material.dart';

import '../data/models/rating_request.dart';
import '../theme/app_text_styles.dart';
import 'movie_log_button.dart';
import 'movie_rating_input.dart';

/// 별점과 코멘트를 입력받는 커스텀 Dialog.
///
/// 평점 **등록**(영화 상세)과 **수정**(내가 등록한 평점)이 같은 Dialog 를 쓴다.
/// 수정일 때는 [initialScore]·[initialComment] 로 기존 값을 채워 열어 준다.
///
/// 저장 로직은 [onSubmit] 콜백으로 받아 **Dialog 안에서** 실행한다. 그래서
/// 저장 중 상태(버튼 잠금·인디케이터·이탈 방지)를 Dialog 가 직접 관리할 수 있다.
///
/// 돌려주는 값:
/// - `true`  — [onSubmit] 이 예외 없이 끝났다. (저장 성공)
/// - `false` — 사용자가 취소했다. [onSubmit] 을 호출하지 않았으므로 요청도 없다.
/// - `null`  — 아직 아무 동작도 하지 않은 채 닫혔다. (뒤로가기 등)
///
/// 바깥 영역 탭으로 닫히는 것은 `PopScope` 가 막지 못하므로, 여는 쪽에서
/// `showDialog(barrierDismissible: false)` 를 함께 지정한다.
class RatingDialog extends StatefulWidget {
  const RatingDialog({
    super.key,
    required this.onSubmit,
    this.movieTitle,
    this.initialScore = 0,
    this.initialComment,
  });

  /// 어느 영화의 평점인지. 모르면(영화 정보 조회 실패) 생략한다.
  final String? movieTitle;

  /// 수정할 때 채워 두는 기존 별점. 등록은 0(아직 고르지 않음)에서 시작한다.
  final int initialScore;

  /// 수정할 때 채워 두는 기존 코멘트. null 이면 빈 칸으로 시작한다.
  final String? initialComment;

  /// 저장 요청. 예외를 던지면 Dialog 가 실패로 처리하고 입력을 유지한다.
  final Future<void> Function(int score, String? comment) onSubmit;

  /// 코멘트 최대 길이.
  static const maxCommentLength = 500;

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  late int _score = widget.initialScore;

  // Controller 는 State 가 살아 있는 동안 **한 번만** 만든다. build 안에서
  // 만들면 별점을 고를 때마다(setState) 다시 만들어져 입력하던 코멘트가 사라지고
  // 커서도 맨 앞으로 돌아간다.
  late final _commentController = TextEditingController(
    text: widget.initialComment ?? '',
  );

  bool _isSubmitting = false;
  String? _errorText;

  bool get _canConfirm => _score > 0 && !_isSubmitting;

  @override
  void dispose() {
    // Dialog 를 여러 번 열고 닫아도 Controller 가 쌓이지 않게 정리한다.
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.movieTitle;

    return PopScope(
      // 저장 중에는 뒤로가기·스와이프로 닫히지 않는다.
      canPop: !_isSubmitting,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null) ...[
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: 8),
              ],
              Text(
                '평점을 남겨주세요',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 20),
              Center(
                child: MovieRatingInput(
                  rating: _score.toDouble(),
                  enabled: !_isSubmitting,
                  // 별점 Widget 이 정수 단위로만 돌려주지만, 값이 계약을 벗어나면
                  // validateServerScore 가 바로 알려 준다.
                  onChanged: (value) => setState(
                    () => _score = validateServerScore(value),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _commentController,
                maxLines: 3,
                maxLength: RatingDialog.maxCommentLength,
                enabled: !_isSubmitting,
                decoration: const InputDecoration(
                  hintText: '코멘트를 남겨보세요 (선택)',
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorText!,
                  style: AppTextStyles.label.copyWith(color: Colors.red),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: MovieLogButton(
                      label: '취소',
                      // 취소를 누르면 onSubmit 을 호출하지 않으므로 요청도 없다.
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MovieLogButton(
                      label: '확인',
                      isLoading: _isSubmitting,
                      // 별점을 고르지 않았으면 코멘트만 썼더라도 누를 수 없다.
                      onPressed: _canConfirm ? _onConfirm : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onConfirm() async {
    final trimmed = _commentController.text.trim();
    if (trimmed.length > RatingDialog.maxCommentLength) {
      setState(() {
        _errorText = '코멘트는 ${RatingDialog.maxCommentLength}자 이하로 입력해 주세요.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      // 빈 코멘트는 빈 문자열이 아니라 null 로 보낸다.
      await widget.onSubmit(_score, trimmed.isEmpty ? null : trimmed);
      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      // 실패해도 입력은 그대로 두고, 버튼만 다시 누를 수 있게 되돌린다.
      // (여기서 _isSubmitting 을 false 로 돌리지 않으면 버튼이 계속 로딩에 멈춘다)
      setState(() {
        _isSubmitting = false;
        _errorText = '저장하지 못했습니다. 잠시 후 다시 시도해 주세요.';
      });
    }
  }
}

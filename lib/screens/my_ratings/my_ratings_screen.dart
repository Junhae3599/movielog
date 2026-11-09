// lib/screens/my_ratings/my_ratings_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/rating_dto.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../view_models/my_ratings_view_model.dart';
import '../../widgets/common_app_bar.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/movie_log_button.dart';
import '../../widgets/rating_dialog.dart';
import 'widgets/delete_rating_dialog.dart';
import 'widgets/my_ratings_empty.dart';
import 'widgets/my_ratings_error.dart';
import 'widgets/my_ratings_loading.dart';
import 'widgets/rating_card.dart';

/// 마이페이지 아래에 열리는 "내가 등록한 평점" 화면.
///
/// 이 Widget 은 상태를 직접 갖지 않는다. 두 서버(자체 백엔드 + TMDB)를 묶는 일과
/// 수정·삭제 요청은 [MyRatingsViewModel] 이 하고, 여기서는 status 에 따라 그리고
/// 사용자 확인(Dialog)을 받는 일만 한다.
///
/// 조회·수정·삭제는 모두 이 화면에서 한다. 평점 **등록**은 영화 상세 화면이다.
/// 조회 대상은 회원가입 결과를 담아 둔 `LearningMemberSession.memberId` 다.
class MyRatingsScreen extends StatefulWidget {
  const MyRatingsScreen({super.key});

  @override
  State<MyRatingsScreen> createState() => _MyRatingsScreenState();
}

class _MyRatingsScreenState extends State<MyRatingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<MyRatingsViewModel>(
      builder: (context, viewModel, child) {
        // 쓰기 결과는 목록 위가 아니라 Snackbar 로 한 번만 알린다.
        // 수정·삭제 실패로 status 가 바뀌어도 놓치지 않도록 화면 최상단에서 본다.
        _showActionMessage(viewModel);

        return PopScope(
          // 여러 건을 지우는 동안에는 화면을 벗어날 수 없다.
          canPop: !viewModel.isDeletingSelected,
          child: Scaffold(
            appBar: CommonAppBar(
              title: '내가 등록한 평점',
              centerTitle: true,
              onBack: () => context.pop(),
              actions: [
                // 지울 평점이 있을 때만 편집 버튼을 보여준다.
                if (viewModel.status == MyRatingsLoadStatus.success)
                  TextButton(
                    onPressed: viewModel.isDeletingSelected
                        ? null
                        : () => viewModel.setEditMode(!viewModel.isEditMode),
                    child: Text(viewModel.isEditMode ? '취소' : '편집'),
                  ),
              ],
            ),
            // 마이페이지 위에 전체 화면으로 열리므로 하단 NavigationBar 를 두지 않는다.
            body: SafeArea(
              child: LoadingOverlay(
                isLoading: viewModel.isDeletingSelected,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 저장은 됐지만 목록을 못 읽은 경우. 재조회 실패로 Error 화면이
                    // 떠도 "저장은 끝났다" 는 사실이 가려지지 않게 위에 둔다.
                    if (viewModel.refreshWarning != null)
                      _Notice(text: viewModel.refreshWarning!),
                    Expanded(
                      child: switch (viewModel.status) {
                        MyRatingsLoadStatus.idle ||
                        MyRatingsLoadStatus.loading =>
                          const MyRatingsLoading(),
                        MyRatingsLoadStatus.error => MyRatingsError(
                            message: viewModel.message,
                            onRetry: viewModel.load,
                          ),
                        MyRatingsLoadStatus.empty => const MyRatingsEmpty(),
                        MyRatingsLoadStatus.success =>
                          _RatingList(viewModel: viewModel),
                      },
                    ),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: viewModel.isEditMode
                ? _DeleteSelectedBar(viewModel: viewModel)
                : null,
          ),
        );
      },
    );
  }

  /// 쓰기 결과 문구가 남아 있으면 이 프레임이 끝난 뒤 Snackbar 로 보여준다.
  ///
  /// build 중에는 ScaffoldMessenger 를 건드릴 수 없어 다음 프레임으로 미룬다.
  void _showActionMessage(MyRatingsViewModel viewModel) {
    if (viewModel.actionMessage == null) return;

    final text = viewModel.consumeActionMessage()!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
    });
  }
}

/// 평점 목록. 안내가 있을 때는 목록 위에 줄을 덧붙인다.
class _RatingList extends StatelessWidget {
  const _RatingList({required this.viewModel});

  final MyRatingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // TMDB 조회가 일부 실패한 경우. 평점 목록은 그대로 두고 알리기만 한다.
        if (viewModel.message != null) _Notice(text: viewModel.message!),
        if (viewModel.isEditMode)
          _Notice(text: '${viewModel.selectedRatingIds.length}개 선택'),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: viewModel.ratings.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final entry = viewModel.ratings[index];
              final rating = entry.rating;

              return RatingCard(
                entry: entry,
                isSelectable: viewModel.isEditMode,
                isSelected: viewModel.isSelected(rating.ratingId),
                onSelectionChanged: () =>
                    viewModel.toggleSelection(rating.ratingId),
                onEdit: () => _onEditPressed(context, entry.movie?.title, rating),
                onDelete: () => _onDeletePressed(context, rating),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 수정 버튼 — 기존 별점·코멘트가 채워진 Dialog 를 다시 연다.
  ///
  /// Dialog 안에서 값을 바꾸는 동안에는 실제 [RatingDto] 를 건드리지 않으므로,
  /// 취소했을 때 되돌릴 상태가 없다.
  Future<void> _onEditPressed(
    BuildContext context,
    String? movieTitle,
    RatingDto rating,
  ) async {
    await showDialog<bool>(
      context: context,
      // 저장 중 바깥 탭으로 닫히는 것도 막는다.
      barrierDismissible: false,
      builder: (_) => RatingDialog(
        movieTitle: movieTitle,
        initialScore: rating.score,
        // null 이면 TextField 가 빈 칸으로 시작한다.
        initialComment: rating.comment,
        // updateRating 이 실패를 rethrow 하면 Dialog 가 그것을 잡아
        // 오류 문구를 보여주고 다시 시도할 수 있게 둔다.
        onSubmit: (score, comment) => viewModel.updateRating(
          ratingId: rating.ratingId,
          score: score,
          comment: comment,
        ),
      ),
    );
  }

  /// 삭제 버튼 — 확인 Dialog 를 먼저 띄운다.
  ///
  /// 취소하면 `onConfirm` 을 호출하지 않으므로 DELETE 요청도 가지 않는다.
  Future<void> _onDeletePressed(BuildContext context, RatingDto rating) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeleteRatingDialog(
        onConfirm: () => viewModel.deleteRating(rating.ratingId),
      ),
    );
  }
}

/// 목록 위에 붙는 안내 줄.
class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.cardFill,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(text, style: AppTextStyles.label),
    );
  }
}

/// 편집 모드에서 화면 아래에 붙는 "선택한 N개 삭제" 버튼. (Challenge)
class _DeleteSelectedBar extends StatelessWidget {
  const _DeleteSelectedBar({required this.viewModel});

  final MyRatingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final count = viewModel.selectedRatingIds.length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: MovieLogButton(
          label: '선택한 $count개 삭제',
          width: double.infinity,
          // 하나 이상 골랐을 때만 활성화한다.
          onPressed: count == 0 || viewModel.isDeletingSelected
              ? null
              : () => _onPressed(context),
        ),
      ),
    );
  }

  /// 다중 삭제는 확인 Dialog 가 **닫힌 뒤** 시작한다. 진행 상태는 Dialog 가
  /// 아니라 화면 위 [LoadingOverlay] 가 보여준다.
  Future<void> _onPressed(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('선택한 평점을 삭제할까요?'),
        content: const Text('삭제한 평점은 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await viewModel.deleteSelectedRatings();
  }
}

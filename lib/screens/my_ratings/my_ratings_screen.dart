// lib/screens/my_ratings/my_ratings_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../view_models/my_ratings_view_model.dart';
import '../../widgets/common_app_bar.dart';
import 'widgets/my_ratings_empty.dart';
import 'widgets/my_ratings_error.dart';
import 'widgets/my_ratings_loading.dart';
import 'widgets/rating_card.dart';

/// 마이페이지 아래에 열리는 "내가 등록한 평점" 화면.
///
/// 이 Widget 은 상태를 직접 갖지 않는다. 두 서버(자체 백엔드 + TMDB)를 묶는 일은
/// [MyRatingsViewModel] 이 하고, 여기서는 status 에 따라 그리기만 한다.
///
/// 화면 이름은 "내가 등록한 평점" 이지만 v5 에는 로그인이 없으므로
/// 학습용 memberId 1 의 공개 데이터를 본다. 그래서 다른 사람의 기록을 고치는
/// 수정·삭제 버튼은 두지 않는다.
class MyRatingsScreen extends StatelessWidget {
  const MyRatingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '내가 등록한 평점',
        centerTitle: true,
        onBack: () => context.pop(),
      ),
      // 마이페이지 위에 전체 화면으로 열리므로 하단 NavigationBar 를 두지 않는다.
      body: SafeArea(
        child: Consumer<MyRatingsViewModel>(
          builder: (context, viewModel, child) => switch (viewModel.status) {
            MyRatingsLoadStatus.idle ||
            MyRatingsLoadStatus.loading =>
              const MyRatingsLoading(),
            MyRatingsLoadStatus.error => MyRatingsError(
                message: viewModel.message,
                onRetry: viewModel.load,
              ),
            MyRatingsLoadStatus.empty => const MyRatingsEmpty(),
            MyRatingsLoadStatus.success => _RatingList(viewModel: viewModel),
          },
        ),
      ),
    );
  }
}

/// 평점 목록. 영화 정보만 일부 빠진 경우에는 목록 위에 안내 줄을 덧붙인다.
class _RatingList extends StatelessWidget {
  const _RatingList({required this.viewModel});

  final MyRatingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final notice = viewModel.message;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // TMDB 조회가 일부 실패한 경우. 평점 목록은 그대로 두고 알리기만 한다.
        if (notice != null)
          Container(
            width: double.infinity,
            color: AppColors.cardFill,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(notice, style: AppTextStyles.label),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: viewModel.ratings.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                RatingCard(entry: viewModel.ratings[index]),
          ),
        ),
      ],
    );
  }
}

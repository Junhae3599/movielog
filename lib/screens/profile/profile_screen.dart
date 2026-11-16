// lib/screens/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../theme/app_text_styles.dart';
import '../../view_models/auth_view_model.dart';
import '../../widgets/common_app_bar.dart';
import '../../widgets/movie_log_button.dart';
import 'widgets/edit_profile_button.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_menu_tile.dart';

/// 마이페이지.
///
/// 8주차에 화면의 출처가 바뀌었다. 1주차의 하드코딩된 '무비러버' 대신
/// `GET /v7/members/me` 로 받은 **내 정보**를 보여준다. 응답에 들어 있는 값은
/// 이메일·닉네임·가입일 셋뿐이라, 1주차 시안의 통계·장르는 더 보여줄 근거가
/// 없어 내렸다. 화면에 있던 숫자를 유지하려고 가짜 값을 만들지 않는다.
///
/// 내 정보를 **불러오는 일은 여기서 하지 않는다.** 세 탭을 모두 감싸는
/// MainShell 이 한 번 호출해 [AuthViewModel.member] 에 담아 두고, 이 화면은
/// 그것을 구독만 한다. 홈을 거치지 않고 마이 탭으로 바로 들어와도 값이 있다.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final member = auth.member;

    return Scaffold(
      appBar: CommonAppBar(
        title: '내 프로필',
        actions: [
          TextButton(
            onPressed: auth.storageCleanupInProgress
                ? null
                : () => _confirmLogout(context, auth),
            child: const Text('로그아웃'),
          ),
        ],
      ),
      body: SafeArea(
        child: switch (member) {
          // Challenge: 불러오는 동안과 실패했을 때를 구분해서 보여준다.
          // 실패를 로딩으로 두면 사용자가 영영 돌아가는 인디케이터만 본다.
          null when auth.memberStatus == MemberLoadStatus.error =>
            _MemberLoadError(
              message: auth.message,
              onRetry: () => auth.loadMember(force: true),
            ),
          null => const Center(child: CircularProgressIndicator()),
          _ => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProfileHeader(
                    nickname: member.nickname,
                    // 소개 자리에 이메일을 넣는다. v7 내 정보에 소개 field 가 없다.
                    introduction: member.email,
                    // Challenge: 가입일 표시.
                    caption: '${_formatJoinedAt(member.createdAt)} 가입',
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.center,
                    // member 가 없으면 수정할 값도 없으므로 그때는 열지 않는다.
                    child: EditProfileButton(
                      onPressed: () => context.push('/my/profile/edit'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 마이페이지 위에 전체 화면으로 열리는 자식 화면이므로 push 로 띄운다.
                  ProfileMenuTile(
                    title: '내가 등록한 평점',
                    onTap: () => context.push('/my/ratings'),
                  ),
                ],
              ),
            ),
        },
      ),
    );
  }

  /// "2026.10.10" 형식. (Challenge)
  ///
  /// 서버가 주는 값은 UTC 일 수 있으므로 기기 시간대로 바꿔 보여준다.
  static String _formatJoinedAt(DateTime createdAt) {
    final local = createdAt.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}.$month.$day';
  }

  /// 로그아웃은 되돌릴 수 없으므로 먼저 확인한다.
  ///
  /// 화면 이동은 하지 않는다. `logout()` 이 상태를 `signedOut` 으로 바꾸면
  /// Router 가 `/login` 으로 보낸다.
  Future<void> _confirmLogout(BuildContext context, AuthViewModel auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('로그아웃할까요?'),
        content: const Text('저장된 로그인 정보가 이 기기에서 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await auth.logout();
  }
}

/// 내 정보를 불러오지 못했을 때. (Challenge)
///
/// 네트워크 실패이므로 **로그아웃시키지 않는다.** 재시도만 제공한다.
class _MemberLoadError extends StatelessWidget {
  const _MemberLoadError({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message ?? '내 정보를 불러오지 못했어요.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 16),
            MovieLogButton(label: '다시 시도', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

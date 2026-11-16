// lib/screens/profile/edit_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../view_models/auth_view_model.dart';
import '../../view_models/edit_profile_view_model.dart';
import '../../widgets/common_app_bar.dart';
import '../../widgets/movie_log_button.dart';
import '../../widgets/movie_log_text_form_field.dart';

/// 프로필 수정 화면. 닉네임만 바꾼다.
///
/// 이메일은 읽기 전용이다. v7 `PATCH /members/me` 가 받는 값이 nickname 뿐이고,
/// 이메일은 로그인 식별자라 바꾸면 계정 자체가 달라진다.
///
/// 실패를 **어디에 보여줄지**로 나눈다.
/// - 입력칸 문제(2~12자, `MEMBER409_1` 중복) → 닉네임 칸 아래 errorText, 입력값 유지
/// - 입력과 무관한 문제(네트워크) → Snackbar, 로그아웃하지 않음
/// - 세션 만료(`AUTH401_2/3/4`) → 세션 정리 후 Router 가 `/login` 으로 이동
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _controller;

  /// 읽기 전용이지만 Controller 가 필요하다. build 안에서 만들면 다시 그릴
  /// 때마다 새 Controller 가 생겨 정리되지 않는다.
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    // 현재 닉네임을 채워 둔다. 빈 칸으로 열면 사용자가 "지워졌나" 로 읽는다.
    final member = context.read<AuthViewModel>().member;
    _controller = TextEditingController(text: member?.nickname ?? '');
    _emailController = TextEditingController(text: member?.email ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final viewModel = context.read<EditProfileViewModel>();
    // await 를 건너면 이 화면이 사라질 수 있다. 화면에 의존하는 객체는 먼저 꺼낸다.
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final success = await viewModel.save(_controller.text);
    if (!mounted) return;

    if (success) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('프로필을 수정했어요.')));
      // 마이페이지는 AuthViewModel.member 를 구독하므로 이미 새 닉네임이 보인다.
      router.pop();
      return;
    }

    // 실패하면 화면에 남아 입력값을 유지한다. 사용자가 고쳐서 바로 다시 저장한다.
    final message = viewModel.consumeMessage();
    if (message == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 변경 내용이 있을 때 뒤로가기를 확인한다. (Challenge)
  Future<bool> _confirmDiscard() async {
    final viewModel = context.read<EditProfileViewModel>();
    if (!viewModel.hasChanges(_controller.text)) return true;

    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('수정을 취소할까요?'),
        content: const Text('저장하지 않은 변경 내용은 사라집니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('계속 수정'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('나가기'),
          ),
        ],
      ),
    );

    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EditProfileViewModel>(
      builder: (context, viewModel, child) {
        final saving = viewModel.isSaving;

        return PopScope(
          // 저장 중에는 닫히지 않는다. 변경 내용이 있으면 확인을 먼저 받는다.
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop || saving) return;

            if (await _confirmDiscard() && context.mounted) context.pop();
          },
          child: Scaffold(
            appBar: CommonAppBar(
              title: '프로필 수정',
              centerTitle: true,
              onBack: saving
                  ? null
                  : () async {
                      if (await _confirmDiscard() && context.mounted) {
                        context.pop();
                      }
                    },
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MovieLogTextFormField(
                      label: '이메일',
                      hintText: '',
                      controller: _emailController,
                      // 읽기 전용. 로그인 식별자라 수정 대상이 아니다.
                      enabled: false,
                      validator: (_) => null,
                    ),
                    const SizedBox(height: 20),
                    MovieLogTextFormField(
                      label: '닉네임',
                      hintText: '2~12자로 입력해 주세요',
                      controller: _controller,
                      enabled: !saving,
                      errorText: viewModel.nicknameError,
                      // 요청을 보내기 전에 거를 수 있는 규칙은 미리 본다.
                      validator: (value) =>
                          viewModel.validateNickname(value ?? ''),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: saving ? null : _submit,
                    ),
                    const Spacer(),
                    MovieLogButton(
                      label: '저장',
                      width: double.infinity,
                      isLoading: saving,
                      onPressed: saving ? null : _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

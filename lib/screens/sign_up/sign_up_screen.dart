// lib/screens/sign_up/sign_up_screen.dart
import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/create_member_request.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../validators/sign_up_validators.dart';
import '../../view_models/learning_member_session.dart';
import '../../view_models/sign_up_view_model.dart';
import '../../view_models/submit_status.dart';
import '../../widgets/common_app_bar.dart';
import '../../widgets/movie_log_button.dart';
import '../../widgets/movie_log_text_form_field.dart';
import 'widgets/sign_up_footer.dart';
import 'widgets/sign_up_header.dart';
import 'widgets/terms_checkbox.dart';

/// 회원가입 화면.
///
/// 입력값과 약관 동의 상태는 화면이 들고 있고, 중복 확인과 회원가입 POST 는
/// [SignUpViewModel] 이 맡는다.
///
/// 가입이 성공하면 응답의 memberId 를 [LearningMemberSession] 에 옮겨 담는다.
/// 이후 영화 상세·마이페이지가 그 값으로 평점 경로를 만든다.
/// 실패는 **목적지가 다르다.** 비밀번호 형식 400 은 비밀번호 입력칸의 errorText,
/// 그 밖의 400·409(최종 중복)는 화면 Snackbar 다.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  /// 이 너비부터 넓은 화면으로 보고 Form 을 가운데로 모은다.
  static const wideBreakpoint = 700.0;

  /// 넓은 화면에서 Form 이 가질 최대 너비.
  static const maxFormWidth = 560.0;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controller 와 FocusNode 는 build 가 아니라 State 에서 한 번만 만든다.
  // build 안에서 만들면 입력할 때마다 커서와 포커스가 초기화된다.
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _agreedToTerms = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    // 만든 순서대로 정리하고 super.dispose() 를 마지막에 호출한다.
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  /// 버튼을 켤지 말지. Validator 와 같은 규칙을 쓴다.
  ///
  /// 형식(Validator)과 별개로 **닉네임·이메일 중복 확인이 모두 통과**해야 하고,
  /// 확인 중이거나 제출 중이면 켜지 않는다. (7주차 Required)
  bool _canSubmit(SignUpViewModel viewModel) =>
      viewModel.isCheckPassed &&
      !viewModel.isBlockedByCheck &&
      SignUpValidators.canSubmit(
        nicknameValue: _nicknameController.text,
        emailValue: _emailController.text,
        passwordValue: _passwordController.text,
        agreedToTerms: _agreedToTerms,
      );

  Future<void> _submit() async {
    // 버튼 활성화 조건과 별개로, 누를 때 Form 전체를 다시 검증한다.
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    // SnackBar 가 키보드에 가려지지 않도록 먼저 닫는다.
    FocusScope.of(context).unfocus();

    final viewModel = context.read<SignUpViewModel>();
    await viewModel.submit(
      CreateMemberRequest(
        email: _emailController.text,
        password: _passwordController.text,
        nickname: _nicknameController.text,
      ),
    );

    // 요청과 화면 전환은 서로 다른 비동기 경계다. await 뒤에는 이 화면이 아직
    // 살아 있는지 다시 확인한다.
    if (!mounted) return;

    if (viewModel.submitStatus == SubmitStatus.success &&
        viewModel.createdMemberId != null) {
      context.read<LearningMemberSession>().setMemberId(
            viewModel.createdMemberId!,
          );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('가입이 완료되었습니다.')),
      );
      // go 는 스택을 교체하므로 가입한 뒤 회원가입 화면으로 돌아갈 수 없다.
      context.go('/movies');
      return;
    }

    // 입력칸에 붙지 않는 오류만 Snackbar 로 알린다. (비밀번호 400 은 errorText)
    final message = viewModel.consumeSnackbarMessage();
    if (message == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold 의 appBar 는 body 바깥이라 LayoutBuilder 로는 판단할 수 없어
    // 창 전체를 보는 MediaQuery 를 쓴다.
    final isWide =
        MediaQuery.sizeOf(context).width >= SignUpScreen.wideBreakpoint;

    // 제출 중에는 뒤로가기·스와이프 백으로 화면을 벗어날 수 없다. 요청이 서버에
    // 도착했는데 결과를 반영할 화면이 사라지는 것을 막는다. (Challenge)
    return PopScope(
      canPop: !context.select<SignUpViewModel, bool>((vm) => vm.isSubmitting),
      child: Scaffold(
        // 회원가입에서는 뒤로 갈 곳이 없으므로 뒤로가기 버튼을 두지 않는다.
        appBar: isWide
            ? null
            : const CommonAppBar(title: '회원가입', centerTitle: true),
        body: SafeArea(
          // Form 이 실제로 쓸 수 있는 공간은 SafeArea 를 지난 뒤에 정해진다.
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 내용이 짧으면 Center 가 세로 가운데로 모으고,
              // 길면 SingleChildScrollView 가 화면을 채우며 스크롤된다.
              return Center(
                child: SingleChildScrollView(
                  // 목록을 끌어내리면 키보드가 닫힌다.
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: SignUpScreen.maxFormWidth,
                    ),
                    // 중복 확인 결과가 바뀌면 Form 만 다시 그린다.
                    child: Consumer<SignUpViewModel>(
                      builder: (context, viewModel, child) => isWide
                          ? _buildForm(viewModel, isWide: true)
                          : _buildNarrowForm(viewModel, constraints),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 좁은 화면에서는 약관과 버튼을 화면 아래에 붙인다.
  ///
  /// Spacer 는 남은 높이를 받아야 늘어나는데 ScrollView 안은 높이가 무한이다.
  /// minHeight 로 화면 높이를 내려주고 IntrinsicHeight 로 확정해 줘야 한다.
  /// 넓은 화면에는 Spacer 가 없으므로 이 장치를 쓰지 않는다. IntrinsicHeight 가
  /// 잡는 예상 높이와 글꼴에 따른 실제 높이가 어긋나면 Overflow 가 난다.
  Widget _buildNarrowForm(
    SignUpViewModel viewModel,
    BoxConstraints constraints,
  ) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
      child: IntrinsicHeight(child: _buildForm(viewModel, isWide: false)),
    );
  }

  Widget _buildForm(SignUpViewModel viewModel, {required bool isWide}) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        // 넓은 화면에서는 내용 높이만 써야 Center 가 가운데로 모을 수 있다.
        mainAxisSize: isWide ? MainAxisSize.min : MainAxisSize.max,
        children: [
          SignUpHeader(showTitle: isWide),
          const SizedBox(height: 32),
          MovieLogTextFormField(
            label: '닉네임',
            hintText: '닉네임을 입력해주세요',
            controller: _nicknameController,
            validator: SignUpValidators.nickname,
            // 형식이 맞아도 서버가 중복이라고 하면 에러 상태를 유지한다.
            errorText: viewModel.nicknameErrorText,
            // 입력창 바깥 오른쪽에 나란히 놓이므로 width 를 주지 않아
            // label 길이에 맞는 내용 기반 크기를 그대로 쓴다.
            trailing: MovieLogButton(
              label: '중복 확인',
              height: MovieLogTextFormField.inputHeight,
              isLoading:
                  viewModel.nicknameCheckStatus == CheckStatus.checking,
              onPressed: viewModel.canCheckNickname
                  ? () => viewModel.checkNickname(_nicknameController.text)
                  : null,
            ),
            nextFocusNode: _emailFocusNode,
            onChanged: (value) {
              // 입력이 바뀌면 이전 확인 결과를 무효화한다.
              viewModel.onNicknameChanged(value);
              setState(() {});
            },
          ),
          _CheckHint(visible: viewModel.nicknameCheckStatus, label: '닉네임'),
          const SizedBox(height: 20),
          MovieLogTextFormField(
            label: '이메일',
            hintText: '이메일 주소를 입력해주세요',
            controller: _emailController,
            focusNode: _emailFocusNode,
            validator: SignUpValidators.email,
            errorText: viewModel.emailErrorText,
            trailing: MovieLogButton(
              label: '중복 확인',
              height: MovieLogTextFormField.inputHeight,
              isLoading: viewModel.emailCheckStatus == CheckStatus.checking,
              onPressed: viewModel.canCheckEmail
                  ? () => viewModel.checkEmail(_emailController.text)
                  : null,
            ),
            keyboardType: TextInputType.emailAddress,
            nextFocusNode: _passwordFocusNode,
            onChanged: (value) {
              viewModel.onEmailChanged(value);
              setState(() {});
            },
          ),
          _CheckHint(visible: viewModel.emailCheckStatus, label: '이메일'),
          const SizedBox(height: 20),
          MovieLogTextFormField(
            label: '비밀번호',
            hintText: '비밀번호를 입력해주세요',
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            validator: SignUpValidators.password,
            // 로컬 validator 가 통과한 뒤에도 서버가 거부한 값이면 계속 에러로
            // 보이도록 ViewModel 의 문구를 errorText 에 연결한다.
            errorText: viewModel.passwordErrorText,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: AppColors.gray,
              ),
              tooltip: _obscurePassword ? '비밀번호 표시' : '비밀번호 숨기기',
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            onChanged: (_) {
              // 값이 바뀌면 서버가 돌려준 400 문구를 지운다.
              viewModel.onPasswordChanged();
              setState(() {});
            },
            onSubmitted: _canSubmit(viewModel) ? _submit : null,
          ),
          // 좁은 화면에서는 약관과 버튼을 아래로 밀어 붙인다.
          if (isWide) const SizedBox(height: 32) else const Spacer(),
          TermsCheckbox(
            value: _agreedToTerms,
            onChanged: (value) => setState(() => _agreedToTerms = value),
          ),
          const SizedBox(height: 16),
          // Form 맨 아래 버튼은 화면 전체 너비를 쓴다.
          MovieLogButton(
            label: '가입하기',
            width: double.infinity,
            isLoading: viewModel.isSubmitting,
            onPressed: _canSubmit(viewModel) ? _submit : null,
          ),
          const SizedBox(height: 24),
          const SignUpFooter(),
        ],
      ),
    );
  }
}

/// 중복 확인에 성공했을 때만 입력창 아래에 뜨는 안내 문구.
///
/// 에러 문구는 입력창의 errorText 가 맡으므로 여기서는 성공만 알린다.
class _CheckHint extends StatelessWidget {
  const _CheckHint({required this.visible, required this.label});

  final CheckStatus visible;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (visible != CheckStatus.available) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Text(
        '사용할 수 있는 $label입니다.',
        style: AppTextStyles.label.copyWith(color: AppColors.violet),
      ),
    );
  }
}

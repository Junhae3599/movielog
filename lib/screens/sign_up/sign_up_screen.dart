// lib/screens/sign_up/sign_up_screen.dart
import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../validators/sign_up_validators.dart';
import '../../widgets/common_app_bar.dart';
import '../../widgets/movie_log_text_form_field.dart';
import 'widgets/sign_up_footer.dart';
import 'widgets/sign_up_header.dart';
import 'widgets/terms_checkbox.dart';

/// 회원가입 화면.
///
/// 입력값과 약관 동의 상태를 화면 안에서만 들고 있으며 API 는 연결하지 않는다.
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
  bool get _canSubmit => SignUpValidators.canSubmit(
        nicknameValue: _nicknameController.text,
        emailValue: _emailController.text,
        passwordValue: _passwordController.text,
        agreedToTerms: _agreedToTerms,
      );

  void _submit() {
    // 버튼 활성화 조건과 별개로, 누를 때 Form 전체를 다시 검증한다.
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    // SnackBar 가 키보드에 가려지지 않도록 먼저 닫는다.
    FocusScope.of(context).unfocus();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('가입이 완료되었습니다.')),
    );

    // go 는 스택을 교체하므로 홈에서 회원가입으로 돌아갈 수 없다.
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold 의 appBar 는 body 바깥이라 LayoutBuilder 로는 판단할 수 없어
    // 창 전체를 보는 MediaQuery 를 쓴다.
    final isWide =
        MediaQuery.sizeOf(context).width >= SignUpScreen.wideBreakpoint;

    return Scaffold(
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
                  child: isWide
                      ? _buildForm(isWide: true)
                      : _buildNarrowForm(constraints),
                ),
              ),
            );
          },
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
  Widget _buildNarrowForm(BoxConstraints constraints) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
      child: IntrinsicHeight(child: _buildForm(isWide: false)),
    );
  }

  Widget _buildForm({required bool isWide}) {
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
            nextFocusNode: _emailFocusNode,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          MovieLogTextFormField(
            label: '이메일',
            hintText: '이메일 주소를 입력해주세요',
            controller: _emailController,
            focusNode: _emailFocusNode,
            validator: SignUpValidators.email,
            keyboardType: TextInputType.emailAddress,
            nextFocusNode: _passwordFocusNode,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          MovieLogTextFormField(
            label: '비밀번호',
            hintText: '비밀번호를 입력해주세요',
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            validator: SignUpValidators.password,
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
            onChanged: (_) => setState(() {}),
            onSubmitted: _canSubmit ? _submit : null,
          ),
          // 좁은 화면에서는 약관과 버튼을 아래로 밀어 붙인다.
          if (isWide) const SizedBox(height: 32) else const Spacer(),
          TermsCheckbox(
            value: _agreedToTerms,
            onChanged: (value) => setState(() => _agreedToTerms = value),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            // null 이면 버튼이 비활성화되고 테마의 disabled 색이 쓰인다.
            onPressed: _canSubmit ? _submit : null,
            child: const Text('가입하기'),
          ),
          const SizedBox(height: 24),
          const SignUpFooter(),
        ],
      ),
    );
  }
}

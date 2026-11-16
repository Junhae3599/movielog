// lib/screens/login/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/preferences/saved_email_preference.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../view_models/auth_view_model.dart';
import '../../widgets/movie_log_button.dart';
import '../../widgets/movie_log_text_form_field.dart';

/// 로그인 화면.
///
/// 이 화면은 [AuthViewModel.login] 만 호출하고 **직접 `context.go('/home')` 을
/// 하지 않는다.** 상태가 `signedIn` 으로 바뀌면 Router 의 `redirect` 가 홈으로
/// 보낸다. 덕분에 로그인·로그아웃·Token 만료 세 경로가 같은 규칙 한 곳을 지난다.
///
/// 세션 만료 안내도 여기서 보여준다. ViewModel 은 "만료됐다" 는 사실만 남기고
/// Snackbar 를 띄우는 일은 화면이 한다. (ViewModel 이 BuildContext 를 들면
/// 화면이 사라진 뒤에도 UI 를 건드리게 된다)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _savedEmail = SavedEmailPreference();

  /// initState 에서 꺼내 둔다. dispose 에서 removeListener 를 하려면
  /// 그때 `context.read` 를 쓸 수 없기 때문이다.
  late final AuthViewModel _auth;

  bool _obscurePassword = true;

  /// "이메일 저장" 체크 여부. (Challenge)
  bool _rememberEmail = false;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthViewModel>();
    _auth.addListener(_showSessionExpired);

    // 이미 만료된 상태로 이 화면이 처음 열리는 경우를 위해 한 번 더 확인한다.
    // (listener 는 '화면이 열려 있는 중에 바뀌는 경우'만 잡는다)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSessionExpired();
      _restoreSavedEmail();
    });
  }

  @override
  void dispose() {
    _auth.removeListener(_showSessionExpired);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _restoreSavedEmail() async {
    final email = await _savedEmail.read();
    if (!mounted || email == null || email.isEmpty) return;

    setState(() {
      _emailController.text = email;
      _rememberEmail = true;
    });
  }

  /// 만료로 쫓겨난 경우에만 안내한다.
  ///
  /// 직접 로그아웃하거나 로그인에 실패한 경우(`AUTH401_1`)에는 `sessionExpired`
  /// 가 켜지지 않으므로 이 Snackbar 가 뜨지 않는다. 셋 다 `signedOut` 이라
  /// 상태만으로는 구분할 수 없어서 플래그를 따로 둔 것이다.
  void _showSessionExpired() {
    if (!mounted || !_auth.sessionExpired) return;

    // 띄우기 **전에** 꺼야 다시 그려질 때 같은 Snackbar 가 반복되지 않는다.
    _auth.consumeSessionExpired();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('로그인이 만료됐어요. 다시 로그인해 주세요.')),
      );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Snackbar 가 키보드에 가려지지 않도록 먼저 닫는다.
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();

    // 비밀번호는 저장하지 않는다. 이메일만, 그것도 체크했을 때만 남긴다.
    if (_rememberEmail) {
      await _savedEmail.save(email);
    } else {
      await _savedEmail.clear();
    }

    await _auth.login(email, _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final loading = auth.status == AuthStatus.authenticating;
    // 저장소 정리 중에도 잠근다. 정리가 끝나기 전에 로그인하면 뒤늦게 실행된
    // delete 가 방금 받은 Token 을 지운다.
    final enabled = !loading && !auth.storageCleanupInProgress;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('로그인'),
        // 로그인 화면은 로그아웃 상태의 시작점이라 뒤로 갈 곳이 없다.
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                SvgPicture.asset(
                  'assets/logos/movielog_logo.svg',
                  width: 72,
                  height: 72,
                  semanticsLabel: 'MovieLog 로고',
                ),
                const SizedBox(height: 20),
                Text(
                  'MovieLog에 로그인',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headline.copyWith(fontSize: 24),
                ),
                const SizedBox(height: 36),
                MovieLogTextFormField(
                  label: '이메일',
                  hintText: 'example@movielog.com',
                  controller: _emailController,
                  enabled: enabled,
                  keyboardType: TextInputType.emailAddress,
                  // 형식까지 여기서 따지지 않는다. 로그인 실패의 최종 판단은
                  // 서버(AUTH401_1)가 하고, 여기서는 빈 칸만 막는다.
                  validator: (value) =>
                      (value?.trim().isEmpty ?? true) ? '이메일을 입력해 주세요.' : null,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),
                MovieLogTextFormField(
                  label: '비밀번호',
                  hintText: '비밀번호를 입력해 주세요',
                  controller: _passwordController,
                  enabled: enabled,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: enabled
                        ? () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          )
                        : null,
                  ),
                  validator: (value) =>
                      (value?.isEmpty ?? true) ? '비밀번호를 입력해 주세요.' : null,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: enabled ? _submit : null,
                ),
                const SizedBox(height: 4),
                // Challenge: 이메일만 저장한다. 비밀번호·Token 은 저장하지 않는다.
                CheckboxListTile(
                  value: _rememberEmail,
                  onChanged: enabled
                      ? (value) =>
                          setState(() => _rememberEmail = value ?? false)
                      : null,
                  title: Text('이메일 저장', style: AppTextStyles.bodyMedium),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                // 로그인 실패 문구. 만료 Snackbar 와 달리 화면에 남는다.
                if (auth.message != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    auth.message!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.label.copyWith(color: AppColors.error),
                  ),
                ],
                const SizedBox(height: 32),
                MovieLogButton(
                  label: '로그인',
                  width: double.infinity,
                  isLoading: loading,
                  onPressed: enabled ? _submit : null,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: enabled ? () => context.push('/sign-up') : null,
                  child: const Text('회원가입'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

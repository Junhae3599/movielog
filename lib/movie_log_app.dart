// lib/movie_log_app.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/network/movie_log_client.dart';
import 'core/network/tmdb_client.dart';
import 'core/storage/token_storage.dart';
import 'data/services/auth_api_service.dart';
import 'data/services/member_api_service.dart';
import 'data/services/rating_api_service.dart';
import 'data/services/sign_up_service.dart';
import 'data/services/tmdb_movie_service.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'view_models/auth_view_model.dart';
import 'view_models/learning_member_session.dart';
import 'view_models/session_rating_store.dart';

class MovieLogApp extends StatelessWidget {
  const MovieLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 8주차: 워크북 Client 를 공개용과 보호용 **둘**로 나눈다.
    // 로그인·중복 확인·공개 평점 조회는 Token 이 필요 없고, 내 정보와 평점
    // 쓰기만 Token 이 필요하다. 하나로 합치면 Token 이 필요 없는 요청에도
    // Header 가 붙는다.
    //
    // TMDB Client 는 계속 별개다. TMDB 요청에 MovieLog JWT 가 실리면 안 된다.
    final tokenStorage = SecureTokenStorage(const FlutterSecureStorage());
    final publicClient = createMovieLogClient();
    final authClient = createAuthMovieLogClient(tokenStorage);

    // MultiProvider 는 MaterialApp.router 를 감싸는 최상단에 둔다.
    //
    // GoRouter 는 화면을 옮길 때마다 그 Route 의 Widget Tree 를 새로 만든다.
    // Provider 가 특정 화면 하위에만 있으면 다른 Route 로 간 화면은
    // context.read 로 그것을 찾지 못하고 오류가 난다.
    return MultiProvider(
      providers: [
        Provider<TokenStorage>.value(value: tokenStorage),
        Provider<TmdbMovieService>(
          create: (_) => TmdbMovieService(createTmdbClient()),
        ),
        // 공개 Client 만 쓰는 Service
        Provider<SignUpService>(
          create: (_) => SignUpService(publicClient),
        ),
        Provider<AuthApiService>(
          create: (_) => AuthApiService(publicClient),
        ),
        // 보호 Client 만 쓰는 Service
        Provider<MemberApiService>(
          create: (_) => MemberApiService(authClient),
        ),
        // 공개 조회와 보호 쓰기를 모두 맡으므로 두 Client 를 받는다.
        Provider<RatingApiService>(
          create: (_) => RatingApiService(publicClient, authClient),
        ),
        ChangeNotifierProvider<AuthViewModel>(
          create: (context) => AuthViewModel(
            context.read<AuthApiService>(),
            context.read<MemberApiService>(),
            context.read<TokenStorage>(),
          ),
        ),
        // 회원가입 응답의 memberId 를 기억해 두는 곳. 공개 평점 조회에만 쓴다.
        ChangeNotifierProvider<LearningMemberSession>(
          create: (_) => LearningMemberSession(),
        ),
        // 인증 세션이 바뀌면 이번 세션에 등록한 평점을 버린다.
        // Proxy 로 묶어 두면 "어디서 비우는지" 를 찾아다닐 필요가 없다.
        ChangeNotifierProxyProvider<AuthViewModel, SessionRatingStore>(
          create: (_) => SessionRatingStore(),
          update: (_, auth, store) =>
              (store ?? SessionRatingStore())..syncSession(auth.sessionVersion),
        ),
      ],
      child: const _MovieLogRouterApp(),
    );
  }
}

/// Router 를 **한 번만** 만들기 위한 호스트.
///
/// `build()` 안에서 `GoRouter` 를 만들면 화면이 다시 그려질 때마다 새 Router 가
/// 생겨 현재 위치가 초기 화면으로 돌아간다. StatefulWidget 의 `initState` 에서
/// 한 번 만들고 필드로 보관한다.
class _MovieLogRouterApp extends StatefulWidget {
  const _MovieLogRouterApp();

  @override
  State<_MovieLogRouterApp> createState() => _MovieLogRouterAppState();
}

class _MovieLogRouterAppState extends State<_MovieLogRouterApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();

    final authViewModel = context.read<AuthViewModel>();
    _router = createRouter(authViewModel);

    // 첫 build 이후에 세션 복원을 시작한다. initState 에서 바로 부르면
    // restoreSession() 의 notifyListeners() 가 build 중에 실행돼 오류가 난다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) authViewModel.restoreSession();
    });
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'MovieLog',
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}

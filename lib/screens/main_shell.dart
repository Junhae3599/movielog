// lib/screens/main_shell.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../view_models/auth_view_model.dart';

/// 홈·영화·마이를 묶는 NavigationBar 셸.
///
/// 어떤 탭이 선택됐는지와 어떤 화면이 보이는지를 navigationShell 하나가
/// 들고 있어 둘이 어긋나지 않는다.
///
/// 8주차에 StatelessWidget 에서 StatefulWidget 이 됐다. 내 정보(`GET
/// /v7/members/me`)를 **여기서 한 번** 불러오기 위해서다.
///
/// 홈 화면의 `initState` 에서 부르지 않은 이유: 닉네임은 홈이 아니라
/// 마이페이지에서 쓰이는데, 로그인 직후 곧바로 `/my` 로 들어가면 홈을 거치지
/// 않아 member 가 빈 채로 남는다. 세 탭을 모두 감싸는 이 Widget 은 탭을 바꿔도
/// 유지되고 `child` 만 바뀌므로 `initState` 가 한 번만 실행된다.
/// 로그아웃 후 다시 로그인하면 셸이 새로 만들어져 다시 호출된다.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  @override
  void initState() {
    super.initState();

    // loadMember() 는 첫 줄에서 notifyListeners() 를 부른다. build 중에
    // 실행되면 "build 중 setState" 오류가 나므로 다음 프레임으로 미룬다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // 어느 탭으로 진입하든 내 정보를 한 번 불러와 AuthViewModel.member 에 담는다.
      // 앱 재시작 흐름은 restoreSession() 이 이미 채워 두었으므로 이 호출은
      // 바로 돌아온다. (force 를 주지 않으면 member 가 있을 때 요청하지 않는다)
      context.read<AuthViewModel>().loadMember();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        // 이미 선택된 탭을 다시 누르면 그 탭의 첫 화면으로 돌아간다.
        onDestinationSelected: (index) => widget.navigationShell.goBranch(
          index,
          initialLocation: index == widget.navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.movie_outlined),
            selectedIcon: Icon(Icons.movie),
            label: '영화',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '마이',
          ),
        ],
      ),
    );
  }
}

// lib/screens/main_shell.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 홈·영화·마이를 묶는 NavigationBar 셸.
///
/// 어떤 탭이 선택됐는지와 어떤 화면이 보이는지를 navigationShell 하나가
/// 들고 있어 둘이 어긋나지 않는다.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        // 이미 선택된 탭을 다시 누르면 그 탭의 첫 화면으로 돌아간다.
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
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

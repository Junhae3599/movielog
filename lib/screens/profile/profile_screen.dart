// lib/screens/profile/profile_screen.dart
import 'package:flutter/material.dart';

import '../../models/profile_stat.dart';
import '../../widgets/common_app_bar.dart';
import 'widgets/edit_profile_button.dart';
import 'widgets/favorite_genres.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_stats.dart';

/// 내 프로필 화면.
///
/// 1주차 화면은 정적이므로 StatelessWidget 을 사용한다.
/// 본문은 의미 단위로 ProfileHeader, EditProfileButton, ProfileStats,
/// FavoriteGenres 로 나누었다.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  /// 통계와 장르는 데이터로 들고 있다가 map 으로 Widget 을 만든다.
  static const _stats = [
    ProfileStat(label: '본 영화', value: '342'),
    ProfileStat(label: '평점', value: '4.2'),
    ProfileStat(label: '즐겨찾기', value: '58'),
  ];

  static const _genres = ['드라마', 'SF', '애니메이션'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(title: '내 프로필'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ProfileHeader(
                imagePath: 'assets/images/profile_movielog.jpg',
                nickname: '무비러버',
                introduction:
                    '매주 주말엔 영화관으로 출근하는 프로 관람객. 좋은 영화를 보고 기록하는 것을 좋아합니다.',
              ),
              const SizedBox(height: 24),
              // 버튼이 가로 전체로 늘어나지 않도록 가운데에만 배치한다.
              const Align(
                alignment: Alignment.center,
                child: EditProfileButton(),
              ),
              const ProfileStats(stats: _stats),
              const FavoriteGenres(genres: _genres),
            ],
          ),
        ),
      ),
    );
  }
}

// lib/screens/profile/widgets/profile_stats.dart
import 'package:flutter/material.dart';

import '../../../models/profile_stat.dart';
import '../../../widgets/stat_item.dart';

/// 통계 카드를 한 줄에 배치하는 영역.
class ProfileStats extends StatelessWidget {
  const ProfileStats({super.key, required this.stats});

  final List<ProfileStat> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      // 위아래 이웃 영역과의 바깥 여백
      margin: const EdgeInsets.symmetric(vertical: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 8,
        // 데이터 목록에서 Widget 을 만든다. 항목이 늘어도 이 코드는 그대로다.
        children: stats
            .map(
              // 고정 너비를 주면 화면 폭을 넘어 RenderFlex Overflow 가 나므로
              // 남은 가로 공간을 카드끼리 똑같이 나눠 갖게 한다.
              (stat) => Expanded(
                child: StatItem(label: stat.label, value: stat.value),
              ),
            )
            .toList(),
      ),
    );
  }
}

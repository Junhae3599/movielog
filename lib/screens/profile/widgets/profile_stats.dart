// lib/screens/profile/widgets/profile_stats.dart
import 'package:flutter/material.dart';

import '../../../widgets/stat_item.dart';

/// 통계 카드 3개를 한 줄에 배치하는 영역.
class ProfileStats extends StatelessWidget {
  const ProfileStats({super.key, required this.stats});

  /// 라벨과 값의 쌍. 개수가 늘어도 같은 코드로 처리된다.
  final List<({String label, String value})> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      // 위아래 이웃 영역과의 바깥 여백
      margin: const EdgeInsets.symmetric(vertical: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final (index, stat) in stats.indexed) ...[
            if (index > 0) const SizedBox(width: 8),
            // 고정 너비를 주면 화면 폭을 넘어 RenderFlex Overflow 가 나므로
            // 남은 가로 공간을 카드끼리 똑같이 나눠 갖게 한다.
            Expanded(
              child: StatItem(label: stat.label, value: stat.value),
            ),
          ],
        ],
      ),
    );
  }
}

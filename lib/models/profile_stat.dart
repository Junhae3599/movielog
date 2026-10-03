// lib/models/profile_stat.dart

/// 프로필 통계 한 칸의 데이터.
///
/// 라벨과 값만 다른 카드가 반복되므로 Widget 대신 데이터로 들고 있다가
/// map 으로 Widget 을 만든다.
class ProfileStat {
  const ProfileStat({required this.label, required this.value});

  final String label;
  final String value;
}

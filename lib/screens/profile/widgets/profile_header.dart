// lib/screens/profile/widgets/profile_header.dart
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// 프로필 이미지, 닉네임, 소개를 보여주는 영역.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.nickname,
    required this.introduction,
    this.imagePath,
  });

  final String nickname;
  final String introduction;

  /// 프로필 이미지 경로. null 이면 기본 아이콘을 보여준다.
  final String? imagePath;

  /// 이미지 안쪽 지름. 둘레의 링 두께 2를 더하면 전체 128이 된다.
  static const double _imageSize = 124;

  @override
  Widget build(BuildContext context) {
    return Column(
      // 교차축(가로) 가운데 정렬
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(2), // 이미지 둘레의 보라색 링
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.lavender,
          ),
          child: ClipOval(child: _buildImage()),
        ),
        const SizedBox(height: 16),
        Text(nickname, style: AppTextStyles.headline),
        const SizedBox(height: 12),
        Text(
          introduction,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildImage() {
    final path = imagePath;

    // 경로가 없으면 이미지를 불러오지 않고 바로 기본 아이콘을 보여준다.
    if (path == null) return const _DefaultProfileIcon(size: _imageSize);

    return Image.asset(
      path,
      width: _imageSize,
      height: _imageSize,
      fit: BoxFit.cover,
      // 경로는 있지만 파일을 읽지 못한 경우에도 같은 아이콘으로 대체한다.
      errorBuilder: (context, error, stackTrace) =>
          const _DefaultProfileIcon(size: _imageSize),
    );
  }
}

/// 프로필 이미지가 없을 때 대신 보여줄 기본 아이콘.
class _DefaultProfileIcon extends StatelessWidget {
  const _DefaultProfileIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: AppColors.lavender,
      alignment: Alignment.center,
      child: Icon(
        Icons.person,
        size: size * 0.55,
        color: AppColors.violet,
      ),
    );
  }
}

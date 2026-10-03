// lib/screens/profile/widgets/profile_header.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// 프로필 이미지, 닉네임, 소개를 보여주는 영역.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.nickname,
    required this.introduction,
  });

  final String nickname;
  final String introduction;

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
          child: ClipOval(
            child: Image.asset(
              'assets/images/profile_movielog.jpg',
              width: 124,
              height: 124,
              fit: BoxFit.cover,
              // 이미지를 불러오지 못하면 기본 아이콘으로 대체한다.
              errorBuilder: (context, error, stackTrace) => Container(
                width: 124,
                height: 124,
                color: AppColors.lavender,
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  'assets/icons/person.svg',
                  width: 56,
                  height: 56,
                  colorFilter: const ColorFilter.mode(
                    AppColors.violet,
                    BlendMode.srcIn,
                  ),
                  semanticsLabel: '기본 프로필 아이콘',
                ),
              ),
            ),
          ),
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
}

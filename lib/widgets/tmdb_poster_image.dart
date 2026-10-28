// lib/widgets/tmdb_poster_image.dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// TMDB 포스터 이미지.
///
/// `poster_path` 는 "/abc.jpg" 처럼 파일 경로만 내려오므로 그대로
/// Image.network 에 넣을 수 없다. base URL 과 size 를 합쳐야 한다.
///
/// URL 조합, null 처리, 로드 실패 처리를 화면마다 반복하지 않도록 이 위젯에 모았다.
class TmdbPosterImage extends StatelessWidget {
  const TmdbPosterImage({
    super.key,
    required this.posterPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String? posterPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  static const _baseUrl = 'https://image.tmdb.org/t/p';
  static const _size = 'w500';

  String? get _imageUrl {
    final path = posterPath;
    if (path == null || path.isEmpty) return null;
    return '$_baseUrl/$_size$path';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _imageUrl;

    final child = imageUrl == null
        // 포스터가 없는 영화
        ? _placeholder()
        : Image.network(
            imageUrl,
            width: width,
            height: height,
            fit: fit,
            // 네트워크가 끊기거나 이미지가 지워진 경우
            errorBuilder: (_, _, _) => _placeholder(),
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : _placeholder(showIcon: false),
          );

    final radius = borderRadius;
    if (radius == null) return child;
    return ClipRRect(borderRadius: radius, child: child);
  }

  Widget _placeholder({bool showIcon = true}) {
    return Container(
      width: width,
      height: height,
      color: AppColors.cardFill,
      alignment: Alignment.center,
      child: showIcon
          ? const Icon(
              Icons.image_not_supported_outlined,
              color: AppColors.gray,
            )
          : null,
    );
  }
}

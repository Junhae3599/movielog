// lib/screens/rating/rating_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common_app_bar.dart';

/// 평점 입력 미니 실습 화면.
///
/// 별점을 고르기 전에는 저장 버튼이 비활성화된다.
class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  /// 0 이면 아직 고르지 않은 상태.
  double _rating = 0;

  bool get _canSave => _rating > 0;

  void _save() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('평점 ${_rating.toStringAsFixed(1)}점을 저장했습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '평점 남기기',
        centerTitle: true,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '이 영화는 어땠나요?',
                textAlign: TextAlign.center,
                style: AppTextStyles.headline,
              ),
              const SizedBox(height: 12),
              Text(
                '별을 눌러 평점을 남겨주세요.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 32),
              // Column 이 stretch 라 감싸지 않으면 별이 가로 전체를 차지하고
              // 왼쪽부터 깔린다.
              Center(
                child: RatingBar.builder(
                  initialRating: _rating,
                  minRating: 0.5,
                  allowHalfRating: true,
                  itemCount: 5,
                  itemSize: 44,
                  glow: false,
                  itemPadding: const EdgeInsets.symmetric(horizontal: 4),
                  itemBuilder: (context, _) =>
                      const Icon(Icons.star, color: AppColors.violet),
                  onRatingUpdate: (rating) => setState(() => _rating = rating),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _canSave ? '${_rating.toStringAsFixed(1)} / 5.0' : '평점을 선택해주세요',
                textAlign: TextAlign.center,
                style: _canSave
                    ? AppTextStyles.statValue
                    : AppTextStyles.bodyMedium,
              ),
              const Spacer(),
              ElevatedButton(
                // 별점을 고르기 전에는 비활성화된다.
                onPressed: _canSave ? _save : null,
                child: const Text('평점 저장'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// lib/screens/movies/widgets/genre_filter_sheet.dart
import 'package:flutter/material.dart';

import '../../../data/mock_movies.dart';
import '../../../theme/app_text_styles.dart';

/// 장르를 여러 개 고를 수 있는 BottomSheet.
///
/// 확인을 누르기 전까지는 시트 안의 선택 상태만 바뀌고 목록에는 반영하지 않는다.
/// 확인을 누르면 고른 장르 집합을 돌려주고, 그냥 닫으면 null 을 돌려준다.
class GenreFilterSheet extends StatefulWidget {
  const GenreFilterSheet({super.key, required this.initialSelection});

  final Set<String> initialSelection;

  @override
  State<GenreFilterSheet> createState() => _GenreFilterSheetState();
}

class _GenreFilterSheetState extends State<GenreFilterSheet> {
  late final Set<String> _selected = {...widget.initialSelection};

  /// 전체는 "필터 없음"을 뜻하므로 고를 대상에서 뺀다.
  static final _options =
      genres.where((genre) => genre != allGenresLabel).toList();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      // 처음에는 화면의 절반만 열리고 위로 끌면 더 펼쳐진다.
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // 끌 수 있다는 걸 알려주는 손잡이
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('장르 선택', style: AppTextStyles.titleMedium),
                  TextButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => setState(_selected.clear),
                    style: TextButton.styleFrom(side: BorderSide.none),
                    child: const Text('초기화'),
                  ),
                ],
              ),
            ),
            // 장르가 많아져도 이 영역만 스크롤된다.
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _options.length,
                itemBuilder: (context, index) {
                  final genre = _options[index];
                  return CheckboxListTile(
                    value: _selected.contains(genre),
                    title: Text(genre, style: AppTextStyles.bodyMedium),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (checked) => setState(() {
                      if (checked ?? false) {
                        _selected.add(genre);
                      } else {
                        _selected.remove(genre);
                      }
                    }),
                  );
                },
              ),
            ),
            // 목록을 스크롤해도 확인 버튼은 아래에 붙어 있다.
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  child: Text(
                    _selected.isEmpty ? '전체 보기' : '${_selected.length}개 장르 보기',
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

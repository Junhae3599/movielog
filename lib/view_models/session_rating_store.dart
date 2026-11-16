// lib/view_models/session_rating_store.dart
import 'package:flutter/foundation.dart';

import '../data/models/rating_dto.dart';

/// 이번 세션에서 내가 쓰기 API 로 만들고 바꾼 평점을 모아 두는 저장소.
///
/// **왜 이런 것이 필요한가.** v7 에는 Token 기반 '내 평점 전체 GET' 이 없다.
/// 공개 유저별 평점 조회는 `/v7/members/{memberId}/ratings` 로 memberId 를
/// 요구하는데, v7 로그인·내 정보 응답에는 memberId 가 없다. 그래서 명세에 없는
/// 값을 지어내지 않는 한, **앱을 껐다 켠 뒤 내 평점 전체를 복원할 방법이 없다.**
///
/// 그 한계를 숨기지 않기로 했다. 등록 응답으로 받은 Rating 객체를 여기에 담아
/// 현재 세션 동안 수정·삭제할 수 있게 하고, "재시작 뒤 전체 복원" 은 계약이
/// 확인되기 전까지 완료 기능으로 표시하지 않는다. (README 참고)
///
/// 메모리에만 둔다. 디스크에 평점 목록을 캐시해 두면 서버 상태와 어긋난 목록을
/// 사용자가 자기 평점이라고 믿게 되므로, 그 쪽이 더 나쁘다.
class SessionRatingStore extends ChangeNotifier {
  final List<RatingDto> _ratings = [];

  /// 마지막으로 맞춰 둔 인증 세션 번호. 바뀌면 들고 있던 평점을 버린다.
  int? _syncedSessionVersion;

  /// 최신 등록순. 서버의 유저별 평점 조회(`ratingId` 내림차순)와 순서를 맞춘다.
  List<RatingDto> get ratings => List.unmodifiable(_ratings);

  bool get isEmpty => _ratings.isEmpty;

  /// 등록·수정 응답으로 받은 Rating 을 반영한다.
  ///
  /// 같은 ratingId 가 이미 있으면 그 자리에서 교체한다. 수정 뒤에 목록 맨 앞으로
  /// 튀어 오르면 사용자가 보던 위치를 잃는다.
  void upsert(RatingDto rating) {
    final index = _ratings.indexWhere(
      (item) => item.ratingId == rating.ratingId,
    );

    if (index >= 0) {
      _ratings[index] = rating;
    } else {
      _ratings.insert(0, rating);
    }
    notifyListeners();
  }

  void remove(int ratingId) {
    final removed = _ratings.length;
    _ratings.removeWhere((item) => item.ratingId == ratingId);
    // 없던 id 를 지우려 한 경우까지 알릴 필요는 없다.
    if (_ratings.length != removed) notifyListeners();
  }

  /// 인증 세션이 바뀌었으면 비운다.
  ///
  /// 로그아웃·회원 전환·만료 뒤에 **이전 계정의 평점이 화면에 남는 것**을 막는다.
  /// `AuthViewModel.sessionVersion` 이 그때마다 올라가므로 그 값만 보면 된다.
  ///
  /// 여기서는 `notifyListeners()` 를 부르지 않는다. 이 메서드는
  /// `ChangeNotifierProxyProvider` 의 `update` 에서, 즉 **build 중에** 불린다.
  /// 그 시점에 알림을 보내면 "build 중 setState" 오류가 난다.
  /// 알림이 없어도 되는 이유는 `update` 가 아래쪽 Widget 들이 그려지기 전에
  /// 실행되기 때문이다. 비운 뒤의 목록을 읽게 되므로 이전 세션의 평점이
  /// 화면에 나타날 틈이 없다.
  void syncSession(int sessionVersion) {
    if (_syncedSessionVersion == sessionVersion) return;

    _syncedSessionVersion = sessionVersion;
    _ratings.clear();
  }
}

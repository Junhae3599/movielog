// lib/view_models/learning_member_session.dart
import 'package:flutter/foundation.dart';

/// 이번 앱 세션에서 **회원가입으로 직접 만든** 회원의 memberId 를 기억한다.
///
/// 7주차까지 이 값은 "현재 회원" 그 자체였다. 평점 경로에 memberId 가 들어갔기
/// 때문이다. 8주차에는 그 역할이 사라졌다. 보호 요청은 Token 으로 요청자를
/// 식별하므로, **로그인 상태를 아는 것은 [AuthViewModel] 하나다.**
///
/// 그래도 지우지 않고 남긴 이유는 하나다. 공개 유저별 평점 조회
/// (`GET /v7/members/{memberId}/ratings`)는 v7 에서도 memberId path 를
/// 유지하는데, 로그인 응답에는 memberId 가 없다. 그 값을 **합법적으로 알 수
/// 있는 유일한 경로**가 회원가입 응답이다.
///
/// 다만 가입한 회원과 지금 로그인한 회원이 다를 수 있으므로, memberId 를
/// 이메일과 **함께** 기억하고 [memberIdFor] 로 둘이 일치할 때만 돌려준다.
/// JWT payload 를 디코딩하거나 명세에 없는 field 를 추정하지 않는다.
///
/// 메모리에만 둔다. 앱을 재시작하면 사라지고, 그때는 공개 조회로 내 평점 전체를
/// 복원할 수 없다. 이 한계는 숨기지 않고 화면에 안내한다.
class LearningMemberSession extends ChangeNotifier {
  int? _memberId;
  String? _email;

  /// 가입 응답에서 받은 memberId 와 그 회원의 이메일을 함께 기억한다.
  void remember({required int memberId, required String email}) {
    _memberId = memberId;
    _email = email.trim().toLowerCase();
    notifyListeners();
  }

  /// 지금 로그인한 회원이 이번 세션에 가입한 그 회원일 때만 memberId 를 준다.
  ///
  /// 이메일이 다르면(=다른 계정으로 로그인했으면) null 이다. 남의 memberId 로
  /// 공개 조회를 보내 **그 사람의 평점을 내 평점으로 보여주는 것**을 막는다.
  int? memberIdFor(String? signedInEmail) {
    if (_memberId == null || _email == null || signedInEmail == null) {
      return null;
    }
    return signedInEmail.trim().toLowerCase() == _email ? _memberId : null;
  }

  void clear() {
    if (_memberId == null && _email == null) return;

    _memberId = null;
    _email = null;
    notifyListeners();
  }
}

// lib/view_models/learning_member_session.dart
import 'package:flutter/foundation.dart';

/// 회원가입으로 만든 **학습용 현재 회원**을 앱 전역에 보관한다.
///
/// 6주차에는 학습용 상수 `memberId = 1` 의 공개 데이터를 봤다. 7주차부터는
/// 내가 가입한 회원의 평점을 쓰기 때문에, 1 을 계속 쓰면 **다른 회원의 경로로**
/// 요청하게 된다. 그래서 가입 결과의 memberId 를 여기에 담고 영화 상세·마이페이지
/// Route 가 같은 값을 읽는다.
///
/// **memberId 를 알고 있다는 사실은 인증이 아니다.** 이 값은 메모리에만 있으므로
/// 앱을 다시 시작하면 사라지고, 다음 JWT 주차에는 보호 요청에서 memberId 경로가
/// 사라지고 서버가 Token 으로 현재 회원을 식별한다.
///
/// 비밀번호는 담지 않는다. (로그·SharedPreferences 에 남기지 않기 위해)
class LearningMemberSession extends ChangeNotifier {
  int? _memberId;

  /// 아직 가입하지 않았으면 null 이다. 화면은 이 값이 null 인 동안
  /// 평점 쓰기 버튼을 비활성화하고 회원가입으로 안내한다.
  int? get memberId => _memberId;

  bool get hasMember => _memberId != null;

  void setMemberId(int id) {
    _memberId = id;
    notifyListeners();
  }

  void clear() {
    _memberId = null;
    notifyListeners();
  }
}

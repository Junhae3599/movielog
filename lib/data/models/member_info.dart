// lib/data/models/member_info.dart
import 'common_response.dart';

/// GET·PATCH /v7/members/me 응답의 `result`.
///
/// 로그인 응답과 마찬가지로 **memberId 가 없다.** 서버가 이미 Token 으로
/// 요청자를 알고 있으니 다시 알려줄 이유가 없다. 화면이 ID 없이 동작하도록
/// 만드는 것이 v7 의 전제다.
class MemberInfo {
  const MemberInfo({
    required this.email,
    required this.nickname,
    required this.createdAt,
  });

  /// 프로필 수정 화면에서 읽기 전용으로 보여준다. (변경 대상이 아니다)
  final String email;

  final String nickname;

  /// 가입일. "2026.10.10 가입" 형식으로 표시한다.
  final DateTime createdAt;

  factory MemberInfo.fromJson(Map<String, dynamic> json) {
    return MemberInfo(
      email: json['email'] as String,
      nickname: json['nickname'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// 내 정보 응답(공통 Wrapper)에서 [MemberInfo] 를 꺼낸다.
///
/// `fetchMe()` 와 `updateNickname()` 이 같은 모양의 응답을 돌려주므로 파싱을
/// 한곳에 모았다. v7 성공 응답은 조회·수정 모두 Wrapper 를 쓴다.
/// (v5 의 중복 확인처럼 Wrapper 가 없는 API 와 섞어 보지 않는다)
MemberInfo parseMemberInfo(Object? data) {
  if (data is! Map<String, dynamic>) {
    throw StateError('내 정보 응답 형식이 올바르지 않습니다.');
  }

  final common = CommonResponse<MemberInfo>.fromJson(
    data,
    (value) => MemberInfo.fromJson(value as Map<String, dynamic>),
  );

  final member = common.result;
  // 2xx 인데 result 가 없는 응답. 성공으로 보면 member 가 null 인 채
  // signedIn 이 되어, 화면이 닉네임을 그릴 수 없게 된다.
  if (member == null) throw StateError('내 정보 result가 없습니다.');

  return member;
}

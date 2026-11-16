// lib/data/services/member_api_service.dart
import 'package:dio/dio.dart';

import '../models/member_info.dart';

/// 내 정보 조회·수정 Service.
///
/// 두 메서드 모두 **보호용 Client** 를 쓴다. URL 에 누구인지 적지 않고
/// `/v7/members/me` 로 보내므로, Header 의 Token 이 빠지면 서버는 요청자를
/// 알 방법이 없다. (그때 돌아오는 것이 `AUTH401_2` 다)
///
/// 이 Service 는 Client 를 하나만 받는다. [RatingApiService] 와 달리 공개
/// 조회가 섞여 있지 않기 때문이다.
class MemberApiService {
  MemberApiService(this._authDio);

  final Dio _authDio;

  /// GET /v7/members/me — 저장된 Token 이 지금도 유효한지 서버에 확인한다.
  ///
  /// 세션 복원의 핵심이 이 호출이다. **Token 문자열이 있다는 이유만으로
  /// 로그인 상태를 확정하지 않는다.** 만료된 Token 으로 홈에 들어가면
  /// 나중에 보호 화면에서 401 을 받고 갑자기 튕긴다.
  Future<MemberInfo> fetchMe() async {
    final response = await _authDio.get('/v7/members/me');
    return parseMemberInfo(response.data);
  }

  /// PATCH /v7/members/me — 닉네임만 수정한다.
  ///
  /// 응답 `result` 가 이미 최신 내 정보이므로, 성공 뒤에 GET me 를 다시
  /// 부르지 않고 이 값으로 메모리의 member 를 교체한다.
  Future<MemberInfo> updateNickname(String nickname) async {
    final response = await _authDio.patch(
      '/v7/members/me',
      data: {'nickname': nickname.trim()},
    );
    return parseMemberInfo(response.data);
  }
}

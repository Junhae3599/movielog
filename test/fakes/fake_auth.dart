// 8주차 인증 테스트용 Fake 모음.
//
// 실제 서버와 기기 저장소 대신 쓴다. Token 저장·조회·삭제가 **언제 몇 번**
// 일어났는지까지 확인할 수 있어야, "네트워크 실패에 Token 을 지우지 않는다"
// 같은 규칙을 테스트로 고정할 수 있다.
import 'package:dio/dio.dart';
import 'package:movielog/core/storage/token_storage.dart';
import 'package:movielog/data/models/login_models.dart';
import 'package:movielog/data/models/member_info.dart';
import 'package:movielog/data/services/auth_api_service.dart';
import 'package:movielog/data/services/member_api_service.dart';

import 'movie_log_fixtures.dart';

/// 메모리에만 저장하는 TokenStorage.
class FakeTokenStorage implements TokenStorage {
  FakeTokenStorage({this.token, this.readThrows = false});

  String? token;

  /// true 면 읽기가 예외를 던진다. (기기 저장소 접근 실패 재현)
  bool readThrows;

  final List<String> saved = [];
  int deleteCount = 0;

  @override
  Future<String?> readAccessToken() async {
    if (readThrows) throw StateError('secure storage unavailable');
    return token;
  }

  @override
  Future<void> saveAccessToken(String value) async {
    token = value;
    saved.add(value);
  }

  @override
  Future<void> deleteAccessToken() async {
    deleteCount++;
    token = null;
  }
}

/// 로그인 결과를 고정하는 Fake.
class FakeAuthApiService implements AuthApiService {
  FakeAuthApiService({
    this.nickname = '무비러버',
    this.accessToken = 'fake.access.token',
    this.error,
    this.delay = Duration.zero,
  });

  String nickname;
  String accessToken;

  /// null 이 아니면 로그인이 이 예외로 실패한다.
  DioException? error;
  Duration delay;

  final List<LoginRequest> calls = [];

  @override
  Future<LoginResult> login(LoginRequest request) async {
    calls.add(request);
    if (delay > Duration.zero) await Future.delayed(delay);

    final failure = error;
    if (failure != null) throw failure;

    return LoginResult(nickname: nickname, accessToken: accessToken);
  }
}

/// 내 정보 조회·수정을 흉내내는 Fake.
class FakeMemberApiService implements MemberApiService {
  FakeMemberApiService({
    MemberInfo? member,
    this.fetchError,
    this.updateError,
    this.delay = Duration.zero,
  }) : member = member ?? fakeMemberInfo();

  MemberInfo member;

  /// null 이 아니면 GET me 가 이 예외로 실패한다.
  DioException? fetchError;

  /// null 이 아니면 PATCH me 가 이 예외로 실패한다.
  DioException? updateError;

  Duration delay;

  int fetchCount = 0;
  final List<String> updateCalls = [];

  @override
  Future<MemberInfo> fetchMe() async {
    fetchCount++;
    if (delay > Duration.zero) await Future.delayed(delay);

    final failure = fetchError;
    if (failure != null) throw failure;

    return member;
  }

  @override
  Future<MemberInfo> updateNickname(String nickname) async {
    updateCalls.add(nickname);
    if (delay > Duration.zero) await Future.delayed(delay);

    final failure = updateError;
    if (failure != null) throw failure;

    member = MemberInfo(
      email: member.email,
      nickname: nickname,
      createdAt: member.createdAt,
    );
    return member;
  }
}

/// 보호 요청의 인증 실패를 만든다. (`AUTH401_2/3/4`)
DioException authError(String code, {int statusCode = 401}) {
  return commonError(
    RequestOptions(path: '/v7/members/me'),
    statusCode,
    code,
    switch (code) {
      'AUTH401_1' => '이메일 또는 비밀번호가 올바르지 않습니다.',
      'AUTH401_3' => '유효하지 않은 토큰입니다.',
      'AUTH401_4' => '만료된 토큰입니다.',
      _ => '로그인이 필요한 요청입니다.',
    },
  );
}

/// 네트워크 실패. **401 이 아니다.**
DioException networkError({String path = '/v7/members/me'}) {
  return DioException(
    requestOptions: RequestOptions(path: path),
    type: DioExceptionType.connectionError,
    message: 'fake network failure',
  );
}

// MemberCheckService 를 대신하는 Fake.
//
// 실제 서버에 중복 확인 요청을 보내지 않고도 ViewModel·화면을 검증할 수 있게 한다.
// (v5 에는 `available: false` 를 만들 수 있는 쓰기 API 가 없으므로 중복 응답은
//  이 Fake 로만 재현할 수 있다)
import 'package:dio/dio.dart';
import 'package:movielog/data/services/member_check_service.dart';

enum FakeCheckMode {
  /// `{"available": true}`
  available,

  /// `{"available": false}`
  duplicated,

  /// 통신 실패 (DioException)
  failure,
}

class FakeMemberCheckService extends MemberCheckService {
  FakeMemberCheckService({
    this.nicknameMode = FakeCheckMode.available,
    this.emailMode = FakeCheckMode.available,
    this.delay = Duration.zero,
  }) : super(Dio());

  FakeCheckMode nicknameMode;
  FakeCheckMode emailMode;

  /// 통신 중 상태를 확인하기 위한 지연.
  Duration delay;

  /// 어떤 값으로 몇 번 물었는지. 재요청을 하지 않는지 검증할 때 쓴다.
  final List<String> nicknameCalls = [];
  final List<String> emailCalls = [];

  @override
  Future<bool> checkNickname(String nickname) =>
      _answer(nickname, nicknameCalls, nicknameMode, '/v5/members/nickname');

  @override
  Future<bool> checkEmail(String email) =>
      _answer(email, emailCalls, emailMode, '/v5/members/email');

  Future<bool> _answer(
    String value,
    List<String> calls,
    FakeCheckMode mode,
    String path,
  ) async {
    calls.add(value.trim());
    if (delay > Duration.zero) await Future.delayed(delay);

    if (mode == FakeCheckMode.failure) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        type: DioExceptionType.connectionError,
        message: 'fake network failure',
      );
    }
    return mode == FakeCheckMode.available;
  }
}

// SignUpService 를 대신하는 Fake.
//
// 실제 서버에 중복 확인·회원가입 요청을 보내지 않고도 ViewModel·화면을 검증할 수
// 있게 한다. (실서버에서는 `available: false` 나 409 를 마음대로 만들 수 없다)
import 'package:dio/dio.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/sign_up_models.dart';
import 'package:movielog/data/services/sign_up_service.dart';

import 'movie_log_fixtures.dart';

enum FakeCheckMode {
  /// `{"available": true}`
  available,

  /// `{"available": false}`
  duplicated,

  /// 통신 실패 (DioException)
  failure,
}

/// 회원가입 POST 가 돌려줄 결과.
enum FakeSignUpMode {
  /// 201 + result 에 회원 정보
  success,

  /// 400 COMMON400 — 비밀번호 형식 위반
  invalidPassword,

  /// 400 COMMON400 — 비밀번호가 아닌 다른 입력 오류
  invalidOther,

  /// 409 COMMON409 — 최종 중복 (이메일을 먼저 검사한다)
  duplicated,

  /// 201 인데 result 가 비어 있는 계약 오류
  missingResult,

  /// 통신 실패 (DioException)
  failure,
}

class FakeSignUpService extends SignUpService {
  FakeSignUpService({
    this.nicknameMode = FakeCheckMode.available,
    this.emailMode = FakeCheckMode.available,
    this.signUpMode = FakeSignUpMode.success,
    this.createdMemberId = 7,
    this.delay = Duration.zero,
  }) : super(Dio());

  FakeCheckMode nicknameMode;
  FakeCheckMode emailMode;
  FakeSignUpMode signUpMode;

  /// 가입 성공 응답이 돌려줄 memberId. 6주차의 1 과 다른 값을 기본으로 두어
  /// 화면이 상수 1 을 계속 쓰고 있지 않은지 드러나게 한다.
  int createdMemberId;

  /// 통신 중 상태를 확인하기 위한 지연.
  Duration delay;

  /// 어떤 값으로 몇 번 물었는지. 재요청을 하지 않는지 검증할 때 쓴다.
  final List<String> nicknameCalls = [];
  final List<String> emailCalls = [];

  /// 회원가입 요청 body 기록. (비밀번호는 출력하지 않고 존재 여부만 확인한다)
  final List<Map<String, dynamic>> signUpCalls = [];

  @override
  Future<bool> checkNickname(String nickname) =>
      _answer(nickname, nicknameCalls, nicknameMode, '/v6/members/nickname');

  @override
  Future<bool> checkEmail(String email) =>
      _answer(email, emailCalls, emailMode, '/v6/members/email');

  @override
  Future<CommonResponse<SignUpResult>> signUp(
    CreateMemberRequest request,
  ) async {
    signUpCalls.add(request.toJson());
    if (delay > Duration.zero) await Future.delayed(delay);

    final options = RequestOptions(path: '/v6/members');

    switch (signUpMode) {
      case FakeSignUpMode.success:
        return CommonResponse<SignUpResult>.fromJson(
          signUpSuccessBody(
            memberId: createdMemberId,
            email: request.email,
            nickname: request.nickname,
          ),
          (value) => SignUpResult.fromJson(value as Map<String, dynamic>),
        );
      case FakeSignUpMode.missingResult:
        // Swagger 예시처럼 result 가 null 인 응답. memberId 를 읽을 수 없다.
        return CommonResponse<SignUpResult>.fromJson(
          commonBody(code: 'COMMON200', message: '성공입니다.'),
          (value) => SignUpResult.fromJson(value as Map<String, dynamic>),
        );
      case FakeSignUpMode.invalidPassword:
        throw commonError(
          options,
          400,
          'COMMON400',
          '비밀번호는 대문자/소문자/숫자/특수문자를 포함한 8자 이상이어야 합니다.',
        );
      case FakeSignUpMode.invalidOther:
        throw commonError(options, 400, 'COMMON400', '입력값이 올바르지 않습니다.');
      case FakeSignUpMode.duplicated:
        throw commonError(options, 409, 'COMMON409', '이미 사용 중인 이메일입니다.');
      case FakeSignUpMode.failure:
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'fake network failure',
        );
    }
  }

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

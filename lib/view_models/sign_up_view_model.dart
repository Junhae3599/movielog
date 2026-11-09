// lib/view_models/sign_up_view_model.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/create_member_request.dart';
import '../data/services/sign_up_service.dart';
import 'submit_status.dart';

/// 중복 확인 한 건이 가질 수 있는 상태.
///
/// 버튼을 누를 수 있는지와 Form 의 에러 문구가 모두 이 하나의 값에서 파생된다.
enum CheckStatus {
  /// 아직 확인하지 않았거나, 입력이 바뀌어 이전 결과가 무효화된 상태.
  idle,

  /// 요청이 진행 중인 상태.
  checking,

  /// 서버가 사용 가능하다고 응답한 상태. (`available: true`)
  available,

  /// 서버가 이미 사용 중이라고 응답한 상태. (`available: false`)
  duplicated,

  /// 통신 자체가 실패한 상태. (DioException)
  error,
}

/// 회원가입 화면 전용 ViewModel.
///
/// 닉네임과 이메일은 같은 화면에 있지만 **상태를 합치지 않는다.** 하나로 합치면
/// 닉네임 확인 결과가 이메일 결과에 영향을 준다.
/// 그래서 같은 구조(`...CheckStatus`, `...ErrorText`, `_duplicated...`)를
/// 필드마다 나란히 둔다.
///
/// 7주차에는 여기에 회원가입 POST([submit])가 더해진다. 가입 실패도 한 상태로
/// 묶지 않고 **오류의 목적지**에 따라 둘로 나눈다. 비밀번호 형식 400 은
/// [passwordErrorText](입력칸), 그 밖의 400·409 는 [snackbarMessage](화면)다.
class SignUpViewModel extends ChangeNotifier {
  SignUpViewModel(this._service);

  final SignUpService _service;

  CheckStatus nicknameCheckStatus = CheckStatus.idle;
  CheckStatus emailCheckStatus = CheckStatus.idle;

  /// 입력창의 errorText 에 그대로 연결할 문구. null 이면 에러 상태가 아니다.
  String? nicknameErrorText;
  String? emailErrorText;

  /// 마지막으로 "중복" 이라고 확인된 값. 같은 값이 다시 들어오면 서버에 다시 묻지
  /// 않고 바로 에러로 되돌린다. (Challenge Mission)
  String? _duplicatedNickname;
  String? _duplicatedEmail;

  /// 지금 입력창에 들어 있는 값. 응답이 돌아왔을 때 그 사이 입력이 바뀌지
  /// 않았는지 확인하는 데 쓴다.
  String _currentNickname = '';
  String _currentEmail = '';

  /// 늦게 도착한 이전 요청의 응답을 무시하기 위한 번호. 필드마다 따로 센다.
  int _nicknameVersion = 0;
  int _emailVersion = 0;

  /// 회원가입 POST 의 진행 상태.
  SubmitStatus submitStatus = SubmitStatus.idle;

  /// 가입 성공 응답에서 읽은 실제 memberId. 화면이 이 값을
  /// [LearningMemberSession] 에 옮겨 담는다.
  int? createdMemberId;

  /// 비밀번호 입력칸의 errorText 에 연결할 문구.
  ///
  /// 400 중 **비밀번호 형식 위반**은 특정 입력칸에 바로 붙일 수 있는 필드 단위
  /// 오류다. 그래서 Snackbar 가 아니라 그 칸에 남겨 둔다.
  String? passwordErrorText;

  /// 어느 입력칸에도 붙일 수 없는 화면 단위 오류 문구. (409 중복 등)
  ///
  /// 한 번 보여준 뒤 화면이 [consumeSnackbarMessage] 로 비운다.
  String? snackbarMessage;

  bool _disposed = false;

  /// 중복 확인 버튼을 누를 수 있는 조건.
  ///
  /// 통신 중이면 중복 요청을 막고, 이미 중복으로 확인된 값이면 값을 바꾸기 전까지
  /// 다시 묻지 않는다.
  bool get canCheckNickname =>
      nicknameCheckStatus != CheckStatus.checking &&
      nicknameCheckStatus != CheckStatus.duplicated;

  bool get canCheckEmail =>
      emailCheckStatus != CheckStatus.checking &&
      emailCheckStatus != CheckStatus.duplicated;

  /// 중복이거나 확인 중인 값으로는 가입을 진행하지 않는다.
  /// (형식 검증은 SignUpValidators 가 따로 맡는다)
  bool get isBlockedByCheck =>
      isSubmitting ||
      nicknameCheckStatus == CheckStatus.checking ||
      nicknameCheckStatus == CheckStatus.duplicated ||
      emailCheckStatus == CheckStatus.checking ||
      emailCheckStatus == CheckStatus.duplicated;

  bool get isSubmitting => submitStatus == SubmitStatus.submitting;

  /// 중복 확인까지 모두 통과했는지. (형식 검증은 SignUpValidators 가 맡는다)
  ///
  /// 7주차부터는 "확인하지 않았다"(idle)도 가입을 막는다. 두 확인이 모두
  /// `available` 이어야 가입하기 버튼이 켜진다.
  bool get isCheckPassed =>
      nicknameCheckStatus == CheckStatus.available &&
      emailCheckStatus == CheckStatus.available;

  void onNicknameChanged(String value) {
    final trimmed = value.trim();
    _currentNickname = trimmed;
    // 값이 바뀌면 이전 가입 시도의 서버 오류(409 등)도 함께 무효화한다.
    _clearSubmitError();
    // 기다리던 이전 요청의 응답을 무효화한다.
    _nicknameVersion++;

    if (_duplicatedNickname != null && trimmed == _duplicatedNickname) {
      // 방금 지운 중복 값을 그대로 다시 입력한 경우. 서버에 다시 묻지 않는다.
      nicknameCheckStatus = CheckStatus.duplicated;
      nicknameErrorText = '이미 사용 중인 닉네임입니다.';
    } else {
      nicknameCheckStatus = CheckStatus.idle;
      nicknameErrorText = null;
    }
    _notify();
  }

  void onEmailChanged(String value) {
    final trimmed = value.trim();
    _currentEmail = trimmed;
    _clearSubmitError();
    _emailVersion++;

    if (_duplicatedEmail != null && trimmed == _duplicatedEmail) {
      emailCheckStatus = CheckStatus.duplicated;
      emailErrorText = '이미 사용 중인 이메일입니다.';
    } else {
      emailCheckStatus = CheckStatus.idle;
      emailErrorText = null;
    }
    _notify();
  }

  Future<void> checkNickname(String value) async {
    final requested = value.trim();
    if (requested.isEmpty ||
        requested != _currentNickname ||
        !canCheckNickname) {
      return;
    }

    final version = ++_nicknameVersion;
    nicknameCheckStatus = CheckStatus.checking;
    nicknameErrorText = null;
    _notify();

    try {
      final available = await _service.checkNickname(requested);
      if (_isStaleNickname(version, requested)) return;

      nicknameCheckStatus =
          available ? CheckStatus.available : CheckStatus.duplicated;
      nicknameErrorText = available ? null : '이미 사용 중인 닉네임입니다.';
      if (!available) _duplicatedNickname = requested;
    } on DioException catch (error) {
      if (_isStaleNickname(version, requested)) return;

      // 통신 실패와 "이미 사용 중"(available: false)은 다른 일이므로 문구도 다르다.
      nicknameCheckStatus = CheckStatus.error;
      nicknameErrorText = writeCheckErrorMessage(error);
    }

    if (!_disposed && version == _nicknameVersion) notifyListeners();
  }

  Future<void> checkEmail(String value) async {
    final requested = value.trim();
    if (requested.isEmpty || requested != _currentEmail || !canCheckEmail) {
      return;
    }

    final version = ++_emailVersion;
    emailCheckStatus = CheckStatus.checking;
    emailErrorText = null;
    _notify();

    try {
      final available = await _service.checkEmail(requested);
      if (_isStaleEmail(version, requested)) return;

      emailCheckStatus =
          available ? CheckStatus.available : CheckStatus.duplicated;
      emailErrorText = available ? null : '이미 사용 중인 이메일입니다.';
      if (!available) _duplicatedEmail = requested;
    } on DioException catch (error) {
      if (_isStaleEmail(version, requested)) return;

      emailCheckStatus = CheckStatus.error;
      emailErrorText = writeCheckErrorMessage(error);
    }

    if (!_disposed && version == _emailVersion) notifyListeners();
  }

  /// 비밀번호를 고치면 서버가 돌려준 400 문구를 지운다.
  ///
  /// 로컬 validator 와 달리 이 문구는 다시 요청해 봐야 알 수 있으므로,
  /// 값이 바뀐 순간 "아직 모르는 상태" 로 되돌린다.
  void onPasswordChanged() {
    passwordErrorText = null;
    _notify();
  }

  /// POST /v6/members.
  ///
  /// 중복 확인 GET 을 통과했더라도 그 사이 다른 사용자가 같은 값을 등록할 수
  /// 있다. 그래서 **이 요청의 409 가 최종 중복 결과**다.
  Future<void> submit(CreateMemberRequest request) async {
    if (isSubmitting) return;

    submitStatus = SubmitStatus.submitting;
    createdMemberId = null;
    passwordErrorText = null;
    snackbarMessage = null;
    _notify();

    try {
      final response = await _service.signUp(request);
      if (_disposed) return;

      final id = response.result?.memberId;
      // result 가 없으면 가입을 완료한 것으로 표시하지 않는다. memberId 없이는
      // 이후 평점 요청의 경로를 만들 수 없기 때문이다.
      if (id == null) throw StateError('회원가입 결과에 memberId가 없습니다.');

      createdMemberId = id;
      submitStatus = SubmitStatus.success;
    } on DioException catch (error) {
      if (_disposed) return;

      submitStatus = SubmitStatus.error;
      final message = writeSignUpErrorMessage(error);
      // 명세의 400 예시는 비밀번호 형식 위반이지만 다른 입력 오류도 400 으로 올
      // 수 있다. 응답 문구가 비밀번호를 가리킬 때만 그 칸에 붙인다.
      if (error.response?.statusCode == 400 && message.contains('비밀번호')) {
        passwordErrorText = message;
      } else {
        snackbarMessage = message;
      }
    } on StateError {
      if (_disposed) return;

      submitStatus = SubmitStatus.error;
      snackbarMessage = '가입 결과를 확인하지 못했습니다. 새 요청 전에 서버 상태를 확인해 주세요.';
    }

    _notify();
  }

  /// Snackbar 문구를 한 번만 꺼내 쓴다. 꺼낸 뒤에는 비워 두어
  /// 화면이 다시 그려질 때 같은 문구가 또 뜨지 않게 한다.
  String? consumeSnackbarMessage() {
    final message = snackbarMessage;
    snackbarMessage = null;
    return message;
  }

  void _clearSubmitError() {
    if (submitStatus == SubmitStatus.error) submitStatus = SubmitStatus.idle;
    snackbarMessage = null;
  }

  /// 화면이 사라졌거나, 새 요청이 시작됐거나, 그 사이 입력이 바뀌었으면 버린다.
  bool _isStaleNickname(int version, String requested) =>
      _disposed ||
      version != _nicknameVersion ||
      _currentNickname != requested;

  bool _isStaleEmail(int version, String requested) =>
      _disposed || version != _emailVersion || _currentEmail != requested;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    // dispose 뒤에 도착할 응답이 상태를 건드리지 않도록 버전을 올려 둔다.
    _nicknameVersion++;
    _emailVersion++;
    super.dispose();
  }
}

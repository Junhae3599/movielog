// lib/view_models/sign_up_view_model.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/services/member_check_service.dart';

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
class SignUpViewModel extends ChangeNotifier {
  SignUpViewModel(this._service);

  final MemberCheckService _service;

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
      nicknameCheckStatus == CheckStatus.checking ||
      nicknameCheckStatus == CheckStatus.duplicated ||
      emailCheckStatus == CheckStatus.checking ||
      emailCheckStatus == CheckStatus.duplicated;

  void onNicknameChanged(String value) {
    final trimmed = value.trim();
    _currentNickname = trimmed;
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
    } on DioException {
      if (_isStaleNickname(version, requested)) return;

      // 통신 실패와 "이미 사용 중"(available: false)은 다른 일이므로 문구도 다르다.
      nicknameCheckStatus = CheckStatus.error;
      nicknameErrorText = '중복 확인에 실패했어요. 다시 시도해 주세요.';
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
    } on DioException {
      if (_isStaleEmail(version, requested)) return;

      emailCheckStatus = CheckStatus.error;
      emailErrorText = '중복 확인에 실패했어요. 다시 시도해 주세요.';
    }

    if (!_disposed && version == _emailVersion) notifyListeners();
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

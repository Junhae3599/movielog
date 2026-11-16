// lib/view_models/auth_view_model.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../core/storage/token_storage.dart';
import '../data/models/login_models.dart';
import '../data/models/member_info.dart';
import '../data/services/auth_api_service.dart';
import '../data/services/member_api_service.dart';

/// 앱 전체의 인증 상태.
///
/// [initializing] 과 [retryRequired] 를 [signedOut] 과 합치지 않은 것이 핵심이다.
/// 저장소를 읽기 전(initializing)에 로그인 화면을 잠깐 보여주면 화면이 튀고,
/// 네트워크 실패(retryRequired)를 로그아웃으로 처리하면 **유효한 Token 을 가진
/// 사용자가 비행기 모드 한 번에 쫓겨난다.**
enum AuthStatus {
  /// 앱 시작 직후. 저장된 Token 을 읽고 서버에 확인하는 중이다.
  initializing,

  /// Token 이 없거나, 만료됐거나, 사용자가 직접 로그아웃했다.
  signedOut,

  /// 로그인 요청을 보내고 응답을 기다리는 중이다.
  authenticating,

  /// 서버가 요청자를 확인해 준 상태.
  signedIn,

  /// 세션 확인에 실패했지만 Token 이 무효라는 근거는 없는 상태. (재시도 가능)
  retryRequired,
}

/// 내 정보(GET me) 로딩 상태.
///
/// [AuthStatus] 와 분리한 이유는 **로그인되어 있는데 내 정보만 못 읽은 상태**가
/// 실제로 존재하기 때문이다. 그 경우 로그아웃시키지 않고 재시도만 하게 한다.
enum MemberLoadStatus { idle, loading, success, error }

/// 로그인·세션 복원·로그아웃을 한곳에서 관리하는 ViewModel.
///
/// 화면 이동은 하지 않는다. 상태만 바꾸고, `/login` 으로 보낼지 `/home` 으로
/// 보낼지는 Router 의 `redirect` 가 정한다. 그래야 로그인·로그아웃·Token 만료
/// 세 경로가 **같은 규칙 한 곳**을 지나간다.
///
/// ViewModel 이 `BuildContext` 로 Snackbar 를 직접 띄우지도 않는다. "세션이
/// 만료됐다" 는 사실만 [sessionExpired] 플래그로 남기고, 보여주는 일은 화면이
/// 한다.
class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._authApi, this._memberApi, this._storage);

  final AuthApiService _authApi;
  final MemberApiService _memberApi;
  final TokenStorage _storage;

  /// 앱은 로그인 상태를 기억한 채 다시 켜지지 않는다. 저장소를 읽기 전까지는
  /// 아무것도 확정할 수 없으므로 initializing 에서 시작한다.
  AuthStatus status = AuthStatus.initializing;

  /// 서버가 확인해 준 내 정보. signedOut 이 되면 비운다.
  MemberInfo? member;

  MemberLoadStatus memberStatus = MemberLoadStatus.idle;

  /// 화면에 보여줄 안내 문구. 로그인 실패 문구와 세션 확인 실패 문구가 모두 들어온다.
  String? message;

  /// 로그인한 회원의 닉네임을 GET me 전에 잠깐 보여주기 위한 값.
  ///
  /// 로그인 응답에 nickname 이 들어 있어, MainShell 이 GET me 를 마치기 전에도
  /// 마이페이지가 빈 칸 대신 이름을 보여줄 수 있다. 서버가 확인해 준 **내 정보**는
  /// 어디까지나 [member] 이고, 이 값은 표시용이다.
  String? loginNickname;

  /// 세션 버전. 로그아웃·회원 전환·만료 때마다 올라간다.
  ///
  /// 이전 세션에서 보낸 요청의 응답이 늦게 도착해 **새 세션을 지우는 것**을 막는다.
  /// (새 계정으로 로그인한 직후 다시 로그아웃되는 증상의 원인이 이것이다)
  int _sessionVersion = 0;
  int get sessionVersion => _sessionVersion;

  /// "만료되어 쫓겨났다" 는 표시. 직접 로그아웃이나 로그인 실패에서는 켜지 않는다.
  ///
  /// 세 경우가 모두 signedOut 이 되므로 **상태만으로는 구분할 수 없어** 따로 둔다.
  bool sessionExpired = false;

  /// 저장소 정리가 진행 중인지. 정리 도중의 새 로그인을 막는다.
  ///
  /// 정리 중에 로그인해 Token 을 저장하면, 뒤늦게 실행된 delete 가 **방금 받은
  /// Token 을 지운다.**
  bool storageCleanupInProgress = false;

  /// 진행 중인 Token 저장 작업. 정리할 때 이것이 끝난 뒤 지운다.
  Future<void>? _tokenWrite;

  bool _disposed = false;

  bool get isSignedIn => status == AuthStatus.signedIn;

  /// 이 응답이 아직 유효한 세션의 것인지.
  bool _isCurrent(int version) => !_disposed && version == _sessionVersion;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// 앱 시작 시 세션을 복원한다.
  ///
  /// 흐름은 "저장소 읽기 → 서버 확인 → 상태 확정" 이다. **Token 이 있다는
  /// 이유만으로 signedIn 으로 넘어가지 않는다.** 이미 만료된 Token 으로 홈에
  /// 들어가면 뒤늦게 401 을 받고 사용자가 영문도 모른 채 튕긴다.
  ///
  /// 실패를 두 갈래로 나누는 것도 중요하다. `AUTH401_2/3/4` 는 Token 이 더는
  /// 쓸모없다는 서버의 확답이므로 세션을 정리하고, 그 밖의 실패(네트워크·타임아웃)는
  /// **Token 을 지우지 않고** 재시도 화면으로 보낸다.
  Future<void> restoreSession() async {
    if (_disposed || storageCleanupInProgress) return;

    final version = ++_sessionVersion;
    status = AuthStatus.initializing;
    message = null;
    member = null;
    loginNickname = null;
    memberStatus = MemberLoadStatus.idle;
    _notify();

    try {
      final token = await _storage.readAccessToken();
      if (!_isCurrent(version)) return;

      if (token == null || token.isEmpty) {
        status = AuthStatus.signedOut;
      } else {
        // 서버 검증. 여기를 통과해야만 signedIn 이다.
        final verified = await _memberApi.fetchMe();
        if (!_isCurrent(version)) return;

        member = verified;
        memberStatus = MemberLoadStatus.success;
        status = AuthStatus.signedIn;
      }
    } on DioException catch (error) {
      if (!_isCurrent(version)) return;

      if (isSessionExpiredCode(apiErrorCode(error))) {
        // Token 이 무효하다는 확답. 저장소까지 정리한다.
        await _clearCurrentSession(expired: true);
        return;
      }

      status = AuthStatus.retryRequired;
      message = '로그인 상태를 확인하지 못했어요. 다시 시도해 주세요.';
    } catch (_) {
      if (!_isCurrent(version)) return;

      // 저장소를 읽지 못한 경우. 서버의 401 과 다른 오류이므로 Token 을 지우지 않는다.
      status = AuthStatus.retryRequired;
      message = '인증 저장소를 읽지 못했어요. 다시 시도해 주세요.';
    }

    if (_isCurrent(version)) _notify();
  }

  /// 로그인한다.
  ///
  /// 최종 흐름은 **로그인 성공 → Token 저장 → signedIn → MainShell 이
  /// loadMember()** 다. 여기서 GET me 를 다시 부르지 않는다. 앱 재시작
  /// ([restoreSession])과 달리, 방금 서버가 발급한 Token 을 같은 요청으로
  /// 한 번 더 확인할 이유가 없다.
  Future<void> login(String email, String password) async {
    if (_disposed ||
        storageCleanupInProgress ||
        status == AuthStatus.authenticating) {
      return;
    }

    status = AuthStatus.authenticating;
    member = null;
    loginNickname = null;
    memberStatus = MemberLoadStatus.idle;
    sessionExpired = false;
    message = null;
    final version = ++_sessionVersion;
    _notify();

    try {
      final result = await _authApi.login(
        LoginRequest(email: email, password: password),
      );
      if (!_isCurrent(version)) return;

      // 저장이 끝나기 전에 signedIn 으로 넘어가면, 보호 요청이 Token 을 읽지
      // 못해 바로 401 을 받는다. 저장을 기다린 뒤 상태를 바꾼다.
      final writing = _storage.saveAccessToken(result.accessToken);
      _tokenWrite = writing;
      try {
        await writing;
      } finally {
        if (identical(_tokenWrite, writing)) _tokenWrite = null;
      }
      if (!_isCurrent(version)) return;

      loginNickname = result.nickname;
      status = AuthStatus.signedIn;
    } on DioException catch (error) {
      if (!_isCurrent(version)) return;

      status = AuthStatus.signedOut;
      // AUTH401_1 은 입력 오류다. 보호 요청의 401 과 같은 문구로 뭉치지 않는다.
      message = apiErrorCode(error) == 'AUTH401_1'
          ? '이메일 또는 비밀번호를 확인해 주세요.'
          : '로그인 요청에 실패했어요. 잠시 후 다시 시도해 주세요.';
    } catch (_) {
      if (!_isCurrent(version)) return;

      // 로그인 자체는 성공했지만 저장에 실패한 경우를 포함한다.
      // Token 을 들고 있어도 재시작하면 사라지므로 로그인됐다고 하지 않는다.
      status = AuthStatus.signedOut;
      message = '로그인 정보를 안전하게 저장하지 못했어요.';
    }

    _notify();
  }

  /// 내 정보를 불러와 [member] 에 보관한다.
  ///
  /// 탭 화면 하나가 아니라 세 탭을 모두 감싸는 MainShell 이 호출한다. 홈
  /// `initState` 에서 부르면, 로그인 후 곧바로 마이 탭으로 들어가는 경우처럼
  /// 홈을 거치지 않을 때 [member] 가 빈 채로 남는다.
  Future<void> loadMember({bool force = false}) async {
    if (status != AuthStatus.signedIn) return;
    if (memberStatus == MemberLoadStatus.loading) return;
    // 앱 재시작 흐름은 restoreSession() 이 이미 member 를 채워 두었다.
    if (member != null && !force) return;

    final version = _sessionVersion;
    memberStatus = MemberLoadStatus.loading;
    _notify();

    try {
      final me = await _memberApi.fetchMe();
      if (!_isCurrent(version)) return; // 로그아웃·회원 전환 뒤 늦게 온 응답은 버린다

      member = me;
      memberStatus = MemberLoadStatus.success;
    } on DioException catch (error) {
      if (!_isCurrent(version)) return;

      if (isSessionExpiredCode(apiErrorCode(error))) {
        await _clearCurrentSession(expired: true);
        return;
      }

      // 네트워크 실패. 로그아웃하지 않고 재시도할 수 있게 둔다.
      memberStatus = MemberLoadStatus.error;
      message = '내 정보를 불러오지 못했어요.';
    } catch (_) {
      if (!_isCurrent(version)) return;

      memberStatus = MemberLoadStatus.error;
      message = '내 정보를 불러오지 못했어요.';
    }

    _notify();
  }

  /// 프로필 수정 성공 응답으로 메모리의 내 정보를 교체한다.
  ///
  /// 수정 응답이 이미 최신 내 정보이므로 GET me 를 다시 부르지 않는다.
  void updateMember(MemberInfo updated) {
    if (_disposed || status != AuthStatus.signedIn) return;

    member = updated;
    loginNickname = updated.nickname;
    notifyListeners();
  }

  /// 다른 ViewModel 이 보호 요청에서 401 을 받았을 때 세션 정리를 요청하는 진입점.
  ///
  /// [_clearCurrentSession] 은 private 이라 밖에서 부를 수 없다. 아무 데서나
  /// 세션을 지우지 못하게 하면서, 꼭 필요한 경로만 이 이름으로 열어 둔다.
  Future<void> expireSession() => _clearCurrentSession(expired: true);

  /// 사용자가 직접 누른 로그아웃.
  ///
  /// 하는 일은 만료와 같지만 [sessionExpired] 를 켜지 않는다. 직접 나간
  /// 사용자에게 "로그인이 만료됐어요" 라고 알릴 이유가 없다.
  ///
  /// 이 기능은 기기의 저장소와 메모리만 비운다. 서버에서 Token 이 즉시
  /// 폐기된다고 보장하지 않는다. (v7 에 로그아웃 API 가 없다)
  Future<void> logout() => _clearCurrentSession(expired: false);

  /// 현재 세션을 끝낸다. (만료·로그아웃 공통)
  ///
  /// 세션 버전을 먼저 올려, 이 시점 이후에 도착하는 **이전 세션의 응답이
  /// 화면을 건드리지 못하게** 한다.
  Future<void> _clearCurrentSession({bool expired = true}) async {
    if (_disposed || storageCleanupInProgress) return;

    final version = ++_sessionVersion;
    storageCleanupInProgress = true;
    member = null;
    loginNickname = null;
    memberStatus = MemberLoadStatus.idle;
    sessionExpired = expired;
    status = AuthStatus.signedOut;
    message = null;
    _notify();

    try {
      // 진행 중이던 저장이 끝난 뒤 지운다. 순서를 지키지 않으면 저장이 삭제보다
      // 늦게 끝나 Token 이 살아남는다.
      try {
        await _tokenWrite;
      } catch (_) {
        // 저장에 실패했더라도 삭제는 시도한다.
      }
      await _storage.deleteAccessToken();
    } catch (_) {
      if (_isCurrent(version)) {
        message = '저장된 인증 정보를 지우지 못했어요. 앱 재실행 전에 저장소 상태를 확인해 주세요.';
      }
    } finally {
      storageCleanupInProgress = false;
      if (_isCurrent(version)) _notify();
    }
  }

  /// 만료 안내를 한 번만 보여주기 위해 표시를 끈다.
  ///
  /// 화면이 Snackbar 를 띄우기 **전에** 부른다. 띄운 뒤에 끄면 그 사이
  /// 다시 그려질 때 같은 Snackbar 가 한 번 더 뜬다.
  void consumeSessionExpired() {
    sessionExpired = false;
  }

  /// 로그인 실패 문구를 한 번 쓰고 비운다.
  void consumeMessage() {
    message = null;
  }

  @override
  void dispose() {
    _disposed = true;
    // 남아 있는 요청의 응답이 dispose 뒤에 notifyListeners() 를 부르지 않게 한다.
    _sessionVersion++;
    super.dispose();
  }
}

// lib/view_models/edit_profile_view_model.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../data/services/member_api_service.dart';
import 'auth_view_model.dart';

enum EditProfileStatus { idle, saving, success, failure }

/// 프로필 수정 화면 전용 ViewModel.
///
/// 오류를 **어디에 보여줄지**에 따라 둘로 나눈다. 특정 입력칸의 문제(길이,
/// 중복)는 [nicknameError] 로 그 칸 아래에, 입력과 무관한 문제(네트워크)는
/// [message] 로 Snackbar 에 보여준다. 한 변수에 담으면 네트워크 오류가
/// 닉네임 칸 아래에 붙는다.
class EditProfileViewModel extends ChangeNotifier {
  EditProfileViewModel(this._memberApi, this._auth);

  final MemberApiService _memberApi;
  final AuthViewModel _auth;

  EditProfileStatus status = EditProfileStatus.idle;

  /// 입력 필드 아래에 보여줄 오류.
  String? nicknameError;

  /// Snackbar 로 보여줄 오류. (네트워크 등)
  String? message;

  bool _disposed = false;

  bool get isSaving => status == EditProfileStatus.saving;

  /// 서버에 보내기 전에 확인할 수 있는 규칙은 클라이언트가 먼저 본다.
  ///
  /// 불필요한 통신을 줄이려는 것이지 서버 검증을 대신하는 것이 아니다.
  /// 규칙이 어긋나면 서버도 `COMMON400` 으로 막는다.
  String? validateNickname(String value) {
    final nickname = value.trim();
    if (nickname.length < 2 || nickname.length > 12) {
      return '닉네임은 2~12자로 입력해 주세요.';
    }
    return null;
  }

  /// 입력한 닉네임이 현재 닉네임과 다른지. (뒤로가기 확인 Dialog 가 쓴다)
  bool hasChanges(String input) => input.trim() != _auth.member?.nickname;

  /// 저장한다. 성공하면 true.
  ///
  /// true 를 돌려받은 화면만 `pop()` 한다. 세션 만료로 실패한 경우에는 false 가
  /// 와서 pop 하지 않고, Router 가 `/login` 으로 보낸다.
  Future<bool> save(String input) async {
    if (status == EditProfileStatus.saving) return false; // 중복 탭 방지
    if (_disposed || !_auth.isSignedIn || _auth.member == null) return false;

    // 응답이 늦게 도착했을 때 그 사이 세션이 바뀌지 않았는지 확인할 기준.
    final version = _auth.sessionVersion;
    final nickname = input.trim();

    nicknameError = validateNickname(nickname);
    if (nicknameError != null) {
      _notify();
      return false;
    }

    // 자기 자신의 현재 닉네임은 중복 검사에서 제외되므로 409 가 나지는 않는다.
    // 그래도 바뀐 것이 없으면 요청을 보낼 이유가 없다.
    if (nickname == _auth.member?.nickname) {
      status = EditProfileStatus.success;
      _notify();
      return true;
    }

    status = EditProfileStatus.saving;
    nicknameError = null;
    message = null;
    _notify();

    try {
      final updated = await _memberApi.updateNickname(nickname);
      if (_disposed || version != _auth.sessionVersion || !_auth.isSignedIn) {
        return false;
      }

      // 마이페이지가 member 를 구독하고 있으므로 화면 이동 없이 새 닉네임이 보인다.
      _auth.updateMember(updated);
      status = EditProfileStatus.success;
      _notify();
      return true;
    } on DioException catch (error) {
      if (_disposed || version != _auth.sessionVersion || !_auth.isSignedIn) {
        return false;
      }

      status = EditProfileStatus.failure;
      final code = apiErrorCode(error);

      if (isSessionExpiredCode(code)) {
        // 세션 만료. 안내와 화면 이동은 로그인 화면과 Router 가 맡는다.
        await _auth.expireSession();
      } else {
        switch (code) {
          case 'MEMBER409_1':
            // 입력값은 그대로 둔다. 사용자가 고쳐서 바로 다시 저장할 수 있다.
            nicknameError = '이미 사용 중인 닉네임이에요.';
          case 'COMMON400' || 'COMMON4001':
            nicknameError = apiErrorMessage(error) ?? '닉네임 형식을 확인해 주세요.';
          case 'MEMBER404_1':
            message = '회원 정보를 찾을 수 없어요.';
          default:
            // 네트워크 실패로는 로그아웃하지 않는다.
            message = '네트워크 상태를 확인하고 다시 시도해 주세요.';
        }
      }
    } catch (_) {
      if (_disposed || version != _auth.sessionVersion) return false;

      status = EditProfileStatus.failure;
      message = '알 수 없는 오류가 발생했어요.';
    }

    _notify();
    return false;
  }

  /// Snackbar 문구를 한 번만 꺼내 쓴다.
  String? consumeMessage() {
    final text = message;
    message = null;
    return text;
  }

  /// 화면이 사라진 뒤 도착한 응답이 notifyListeners() 를 부르지 않게 막는다.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

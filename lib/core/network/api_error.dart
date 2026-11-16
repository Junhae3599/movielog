// lib/core/network/api_error.dart
import 'package:dio/dio.dart';

/// v7 실패 응답의 `code` 를 꺼낸다.
///
/// 7주차부터 실패 응답의 code 가 도메인별로 갈라졌다(`AUTH401_2`, `RATING403_1` …).
/// **status 만 보면 처리를 나눌 수 없다.** 같은 401 이 로그인 입력 오류일 수도,
/// 보호 요청의 Token 만료일 수도 있기 때문이다. 앞의 것은 Form 오류이고
/// 뒤의 것만 세션 정리 대상이다.
///
/// body 가 공통 형식이 아닐 수도 있고(프록시 오류·타임아웃) 아예 없을 수도 있다.
/// 그 경우 null 을 돌려주고, 호출한 쪽은 "분기할 근거가 없다" 로 보고
/// 기본 처리(재시도 안내)를 한다. **네트워크 실패는 401 이 아니다.**
String? apiErrorCode(DioException error) {
  final data = error.response?.data;
  if (data is! Map<String, dynamic>) return null;

  final code = data['code'];
  return code is String ? code : null;
}

/// v7 실패 응답의 `message` 를 꺼낸다.
///
/// 서버가 이미 사용자에게 보여줄 문장을 만들어 둔 오류(닉네임 길이 같은
/// `COMMON400`)는 우리 문구를 새로 만들지 않고 이 값을 그대로 입력칸 아래에 쓴다.
String? apiErrorMessage(DioException error) {
  final data = error.response?.data;
  if (data is! Map<String, dynamic>) return null;

  final message = data['message'];
  return message is String ? message : null;
}

/// 보호 요청에서 "현재 세션을 더 이상 쓸 수 없다" 는 뜻의 code 인지.
///
/// - `AUTH401_2` — Token 을 보내지 않았다
/// - `AUTH401_3` — 서명이 맞지 않는다 (위조·손상)
/// - `AUTH401_4` — 만료됐다
///
/// **`AUTH401_1` 은 포함하지 않는다.** 그것은 로그인 Form 의 이메일·비밀번호
/// 오류이므로 세션을 정리하거나 만료 안내를 띄울 일이 아니다. 401 을 전부 한
/// 처리로 묶으면 로그인 실패 한 번에 "로그인이 만료됐어요" Snackbar 가 뜬다.
///
/// 403(`RATING403_1`)도 여기에 들어가지 않는다. 그쪽은 인증은 됐지만 남의
/// 자원이라는 **인가** 실패이므로, 안내만 하고 로그인 상태를 유지한다.
bool isSessionExpiredCode(String? code) {
  return code == 'AUTH401_2' || code == 'AUTH401_3' || code == 'AUTH401_4';
}

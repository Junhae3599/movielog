// lib/core/network/auth_interceptor.dart
import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// 보호 요청에만 `Authorization: Bearer {token}` 을 붙이는 Interceptor.
///
/// **모든 요청에 무조건 Token 을 붙이지 않는다.** 붙이는 대상은 화면도, 개별
/// API 메서드도 아니라 **Client(Dio 인스턴스) 하나**다. 그래서 이 Interceptor
/// 는 보호용 Client 에만 등록하고(`createAuthMovieLogClient`), 로그인·중복
/// 확인처럼 Token 이 필요 없는 요청을 보내는 공개용 Client 에는 등록하지 않는다.
///
/// 그래도 host·path 를 한 번 더 확인하는 이유는, 보호용 Client 로 실수로
/// 외부 URL(TMDB·포스터 이미지)을 부르는 코드가 생기면 **우리 Token 이 남의
/// 서버로 새 나가기** 때문이다. baseUrl 과 무관하게 절대 URL 로 요청하면
/// baseUrl 이 무시되므로, 등록 위치만으로는 그 경우를 막을 수 없다.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage, {this.host = defaultHost});

  /// MovieLog 워크북 서버의 host. 이 host 가 아니면 Token 을 붙이지 않는다.
  static const defaultHost = 'workbook.devnoco.com';

  final TokenStorage _storage;
  final String host;

  /// Token 을 실어야 하는 요청인지.
  ///
  /// 유저별 평점 조회(`/v7/members/{memberId}/ratings`)는 공개 API 라 여기에
  /// 없다. 그래서 실수로 보호용 Client 로 보내도 Token 이 붙지 않는다.
  bool _isProtected(RequestOptions options) {
    final uri = options.uri;
    if (uri.host != host) return false;

    final path = uri.path;
    return path == '/v7/members/me' ||
        path == '/v7/ratings' ||
        path.startsWith('/v7/ratings/');
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isProtected(options)) {
      handler.next(options);
      return;
    }

    // 이전 요청에서 넘어온 Header 를 그대로 재사용하지 않는다.
    // (로그아웃·회원 전환 뒤에 남은 옛 Token 이 실려 나가는 것을 막는다)
    options.headers.remove('Authorization');

    try {
      final token = await _storage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      // Token 이 없어도 요청은 보낸다. 서버의 AUTH401_2 로 상태를 확정한다.
      // Token 문자열의 존재만으로 로그인 상태를 판단하지 않는 것과 같은 이유다.
      handler.next(options);
    } catch (error) {
      // 기기 저장소를 읽지 못한 것은 **서버의 401 과 다른 오류**다.
      // 401 로 바꿔 전달하면 네트워크·저장소 문제로 사용자를 로그아웃시키게 된다.
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: StateError('인증 저장소를 읽지 못했습니다.'),
        ),
      );
    }
  }
}

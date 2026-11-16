// AuthInterceptor — Bearer Header 를 어디에 붙이고 어디에 붙이지 않는가 (8주차)
//
// 이 파일이 지키는 규칙은 하나다. **Token 은 MovieLog 보호 경로에만 간다.**
// TMDB·포스터 CDN·공개 API 로 새 나가면 안 된다.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/core/network/auth_interceptor.dart';

import 'fakes/fake_auth.dart';

/// Interceptor 만 통과시키고 요청을 실제로 보내지는 않는다.
///
/// `onRequest` 에서 응답을 바로 돌려주면(resolve) 네트워크로 나가지 않으므로,
/// Header 가 어떻게 바뀌었는지만 확인할 수 있다.
Dio buildClient(FakeTokenStorage storage) {
  final dio = Dio(BaseOptions(baseUrl: 'https://workbook.devnoco.com'));
  dio.interceptors.add(AuthInterceptor(storage));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response<dynamic>(requestOptions: options, statusCode: 200),
      ),
    ),
  );
  return dio;
}

String? authorizationOf(Response<dynamic> response) =>
    response.requestOptions.headers['Authorization'] as String?;

void main() {
  test('보호 경로에는 Bearer Token 을 붙인다', () async {
    final dio = buildClient(FakeTokenStorage(token: 'abc.def.ghi'));

    for (final path in ['/v7/members/me', '/v7/ratings', '/v7/ratings/12']) {
      final response = await dio.get<dynamic>(path);
      expect(authorizationOf(response), 'Bearer abc.def.ghi', reason: path);
    }
  });

  test('공개 유저별 평점 조회에는 붙이지 않는다', () async {
    final dio = buildClient(FakeTokenStorage(token: 'abc.def.ghi'));

    // 보호 경로 목록에 없으므로, 실수로 보호용 Client 로 보내도 Token 이 안 붙는다.
    final response = await dio.get<dynamic>('/v7/members/7/ratings');

    expect(authorizationOf(response), isNull);
  });

  test('로그인·중복 확인 같은 공개 경로에는 붙이지 않는다', () async {
    final dio = buildClient(FakeTokenStorage(token: 'abc.def.ghi'));

    for (final path in ['/v7/auth/login', '/v6/members', '/v6/members/email/a']) {
      final response = await dio.get<dynamic>(path);
      expect(authorizationOf(response), isNull, reason: path);
    }
  });

  test('다른 host 로 나가는 요청에는 붙이지 않는다', () async {
    final dio = buildClient(FakeTokenStorage(token: 'abc.def.ghi'));

    // baseUrl 이 무엇이든 절대 URL 이면 그쪽으로 나간다.
    // 우리 Token 이 TMDB 나 이미지 CDN 으로 새면 안 된다.
    final tmdb = await dio.get<dynamic>(
      'https://api.themoviedb.org/3/movie/550',
    );
    expect(authorizationOf(tmdb), isNull);

    final image = await dio.get<dynamic>('https://image.tmdb.org/t/p/w500/a.jpg');
    expect(authorizationOf(image), isNull);
  });

  test('Token 이 없으면 Header 없이 보내고 서버의 401 로 판단한다', () async {
    final dio = buildClient(FakeTokenStorage());

    final response = await dio.get<dynamic>('/v7/members/me');

    // Token 문자열의 유무로 로그인 상태를 확정하지 않는다.
    expect(authorizationOf(response), isNull);
    expect(response.statusCode, 200);
  });

  test('이전 요청의 Authorization 을 재사용하지 않는다', () async {
    final storage = FakeTokenStorage(token: 'new.token');
    final dio = buildClient(storage);

    // 로그아웃 전 세션의 Header 가 남아 있는 상황.
    final response = await dio.get<dynamic>(
      '/v7/members/me',
      options: Options(headers: {'Authorization': 'Bearer old.token'}),
    );

    expect(authorizationOf(response), 'Bearer new.token');
  });

  test('저장소 읽기 실패는 요청을 막고 401 로 바꾸지 않는다', () async {
    final dio = buildClient(FakeTokenStorage(readThrows: true));

    try {
      await dio.get<dynamic>('/v7/members/me');
      fail('요청이 거절돼야 합니다');
    } on DioException catch (error) {
      // 기기 저장소 실패를 401 로 바꾸면 사용자가 로그아웃된다.
      expect(error.response, isNull);
      expect(error.error, isA<StateError>());
    }
  });
}

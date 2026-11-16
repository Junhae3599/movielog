// lib/core/network/movie_log_client.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../storage/token_storage.dart';
import 'api_logging_interceptor.dart';
import 'auth_interceptor.dart';

/// MovieLog 자체 백엔드(워크북 API) 전용 Dio Client.
///
/// TMDB Client 와 **절대 하나로 합치지 않는다.** baseUrl 이 다르고, TMDB 는
/// 모든 요청에 TMDB Read Access Token 을 달지만 MovieLog 보호 요청에는
/// MovieLog JWT 를 달아야 한다. 두 Authorization Header 를 섞으면 우리 Token 이
/// TMDB 로, TMDB Token 이 우리 서버로 간다.
///
/// 8주차부터 이 서버용 Client 가 **둘**로 나뉘었다. v6 까지는 인증이 없어 하나로
/// 충분했지만, v7 보호 API 가 생기면서 Token 을 붙이는 Client 와 붙이지 않는
/// Client 를 분리했다. Client 가 둘이 되어도 TMDB Client 와는 계속 별개다.
BaseOptions _movieLogOptions() {
  return BaseOptions(
    baseUrl: 'https://workbook.devnoco.com',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'accept': 'application/json'},
  );
}

/// 공개 요청용 Client — 로그인, 중복 확인, 유저별 평점 조회.
///
/// [AuthInterceptor] 를 등록하지 않는다. Token 이 필요 없는 요청에 Header 를
/// 붙이면, 만료된 Token 때문에 공개 조회까지 실패할 수 있다.
Dio createMovieLogClient() {
  final dio = Dio(_movieLogOptions());

  if (kDebugMode) {
    dio.interceptors.add(const ApiLoggingInterceptor('MovieLog'));
  }

  return dio;
}

/// 보호 요청용 Client — 내 정보 조회·수정, 평점 등록·수정·삭제.
///
/// Interceptor 는 클래스를 만드는 것만으로 동작하지 않는다. 요청을 보내는
/// Client 의 `interceptors` 에 등록해야 그 Client 를 지나가는 모든 요청에
/// 적용된다. 그 등록이 여기 한 줄이다.
Dio createAuthMovieLogClient(TokenStorage storage) {
  final dio = Dio(_movieLogOptions());

  // 로깅보다 **앞**에 두어 Header 가 붙은 뒤의 요청이 로그를 타게 한다.
  // (ApiLoggingInterceptor 는 Token 을 그대로 찍지 않는다)
  dio.interceptors.add(AuthInterceptor(storage));

  if (kDebugMode) {
    dio.interceptors.add(const ApiLoggingInterceptor('MovieLog(auth)'));
  }

  return dio;
}

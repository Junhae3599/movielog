// lib/core/network/movie_log_client.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_logging_interceptor.dart';

/// MovieLog 자체 백엔드(워크북 API) 전용 Dio Client.
///
/// TMDB Client 와 **절대 하나로 합치지 않는다.** baseUrl 이 다르고,
/// TMDB 는 모든 요청에 Read Access Token 을 Header 로 달지만 이 서버의 v5 는
/// 인증이 없다. (JWT 주차부터 이 Client 에만 Access Token 을 달게 된다)
///
/// `MemberCheckService` 와 `RatingApiService` 는 같은 서버를 부르므로
/// 이 함수로 만든 인스턴스 **하나**를 공유한다.
Dio createMovieLogClient() {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://workbook.devnoco.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'accept': 'application/json'},
    ),
  );

  if (kDebugMode) {
    dio.interceptors.add(const ApiLoggingInterceptor('MovieLog'));
  }

  return dio;
}

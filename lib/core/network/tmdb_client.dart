// lib/core/network/tmdb_client.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/tmdb_config.dart';
import 'tmdb_logging_interceptor.dart';

/// TMDB 전용 Dio Client.
///
/// MovieLog 자체 API(회원·평점·즐겨찾기)는 인증 방식이 다르므로
/// 같은 Client 를 쓰지 않고 TMDB 용을 따로 만든다.
Dio createTmdbClient() {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.themoviedb.org/3',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Authorization': 'Bearer ${TmdbConfig.accessToken}',
        'accept': 'application/json',
      },
    ),
  );

  // 로그는 개발 중 확인 용도이므로 release 모드에서는 달지 않는다.
  if (kDebugMode) {
    dio.interceptors.add(TmdbLoggingInterceptor());
  }

  return dio;
}

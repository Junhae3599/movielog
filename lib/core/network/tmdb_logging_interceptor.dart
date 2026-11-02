// lib/core/network/tmdb_logging_interceptor.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// TMDB Client 를 거치는 모든 요청·응답을 같은 형식으로 기록한다.
///
/// 화면마다 따로 로그를 찍으면 형식이 달라지고 특정 화면만 로그가 빠지기 쉽다.
/// Client 에 Interceptor 하나를 등록해 두면 모든 호출이 같은 지점을 통과한다.
///
/// Interceptor 는 기록만 남긴다. 그 로그를 어디서 볼지는 개발 환경(콘솔,
/// Network Inspector)에 맡긴다.
class TmdbLoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Authorization 원문이 찍히면 콘솔 로그나 화면 녹화로 Token 이 노출된다.
    final maskedHeaders = Map<String, dynamic>.from(options.headers);
    if (maskedHeaders.containsKey('Authorization')) {
      maskedHeaders['Authorization'] = 'Bearer ***';
    }

    debugPrint('[TMDB 요청] ${options.method} ${options.uri}');
    debugPrint('[TMDB 요청 Header] $maskedHeaders');
    if (options.queryParameters.isNotEmpty) {
      debugPrint('[TMDB 요청 Query] ${options.queryParameters}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint(
      '[TMDB 응답] ${response.statusCode} ${response.requestOptions.uri}',
    );
    debugPrint('[TMDB 응답 Body] ${response.data}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 실패한 요청을 재현할 수 있도록 URL 과 오류 메시지를 함께 남긴다.
    debugPrint('[TMDB 오류] ${err.requestOptions.uri}');
    debugPrint('[TMDB 오류 status] ${err.response?.statusCode}');
    debugPrint('[TMDB 오류 내용] ${err.message}');
    handler.next(err);
  }
}

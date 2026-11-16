// lib/core/network/api_logging_interceptor.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Dio Client 를 거치는 모든 요청·응답을 같은 형식으로 기록한다.
///
/// 화면마다 따로 로그를 찍으면 형식이 달라지고 특정 화면만 로그가 빠지기 쉽다.
/// Client 에 Interceptor 하나를 등록해 두면 모든 호출이 같은 지점을 통과한다.
///
/// Interceptor 는 기록만 남긴다. 그 로그를 어디서 볼지는 개발 환경(콘솔,
/// Network Inspector)에 맡긴다.
///
/// 6주차에 MovieLog 자체 백엔드 Client 가 생기면서, 서버 이름만 다르고 하는 일이
/// 같은 Interceptor 를 두 개 두지 않도록 [tag] 를 받는 하나로 합쳤다.
class ApiLoggingInterceptor extends Interceptor {
  const ApiLoggingInterceptor(this.tag);

  /// 로그 앞에 붙는 서버 이름. 어느 Client 의 호출인지 구분한다. (TMDB / MovieLog)
  final String tag;

  /// 로그에 원문이 남으면 안 되는 key. (8주차)
  ///
  /// Header 만 가리는 것으로는 부족하다. **로그인 성공 응답의 body 에
  /// `accessToken` 원문이 들어 있기 때문이다.** Body 를 그대로 찍으면
  /// Header 를 가린 의미가 없어진다.
  static const _maskedKeys = {'accessToken', 'password', 'authorization'};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Authorization 원문이 찍히면 콘솔 로그나 화면 녹화로 Token 이 노출된다.
    final maskedHeaders = Map<String, dynamic>.from(options.headers);
    if (maskedHeaders.containsKey('Authorization')) {
      maskedHeaders['Authorization'] = 'Bearer ***';
    }

    debugPrint('[$tag 요청] ${options.method} ${options.uri}');
    debugPrint('[$tag 요청 Header] $maskedHeaders');
    if (options.queryParameters.isNotEmpty) {
      debugPrint('[$tag 요청 Query] ${options.queryParameters}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint(
      '[$tag 응답] ${response.statusCode} ${response.requestOptions.uri}',
    );
    debugPrint('[$tag 응답 Body] ${_mask(response.data)}');
    handler.next(response);
  }

  /// Body 를 재귀적으로 훑어 민감한 값만 `***` 로 바꾼 사본을 만든다.
  ///
  /// 원본을 수정하지 않는다. 로그를 위해 응답 데이터를 건드리면 화면이 쓰는
  /// 값까지 `***` 가 된다.
  Object? _mask(Object? data) {
    if (data is Map) {
      return {
        for (final entry in data.entries)
          entry.key: _maskedKeys.contains('${entry.key}')
              ? '***'
              : _mask(entry.value),
      };
    }
    if (data is List) return data.map(_mask).toList();
    return data;
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 실패한 요청을 재현할 수 있도록 URL 과 오류 메시지를 함께 남긴다.
    debugPrint('[$tag 오류] ${err.requestOptions.uri}');
    debugPrint('[$tag 오류 status] ${err.response?.statusCode}');
    debugPrint('[$tag 오류 내용] ${err.message}');
    // 응답 Body 에 서버가 보낸 실패 이유(message/error/statusCode)가 들어 있다.
    debugPrint('[$tag 오류 Body] ${err.response?.data}');
    handler.next(err);
  }
}

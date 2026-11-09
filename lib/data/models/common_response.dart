// lib/data/models/common_response.dart

/// v6 부터 등장한 공통 응답 Wrapper.
///
/// 회원가입·평점 등록·평점 수정의 **성공** 응답과, v6 의 **모든 실패** 응답이
/// 이 네 필드로 내려온다.
///
/// ```json
/// { "isSuccess": true, "code": "COMMON200", "message": "성공입니다.", "result": {...} }
/// ```
///
/// 반대로 v5 부터 있던 닉네임·이메일 확인과 회원별 평점 조회는 성공 시 직접
/// 객체/배열을 그대로 돌려준다. (`CheckResult` / `List<RatingDto>`)
/// 그래서 "v6 이면 전부 이 Wrapper" 가 아니라 **API 별 성공 계약**에 맞춰 파싱한다.
///
/// [result] 에 담기는 값은 API 마다 다르므로 제네릭 [T] 로 둔다. 실패 응답이거나
/// 돌려줄 데이터가 없는 API(평점 수정)에서는 null 이다.
class CommonResponse<T> {
  const CommonResponse({
    required this.isSuccess,
    required this.code,
    required this.message,
    this.result,
  });

  final bool isSuccess;

  /// 처리 결과 code. (`COMMON200`, `COMMON400`, `COMMON409` ...)
  ///
  /// 화면 문구로 쓰지 않는다. 같은 `COMMON404` 가 등록에서는 "없는 유저",
  /// 수정·삭제에서는 "없는 평점" 을 가리키기 때문이다. code 는 **그 다음 UI
  /// 행동**(목록을 다시 조회할지)을 정하는 데만 쓴다.
  final String code;

  /// 서버가 만들어 둔 사용자 안내 문구. 오류 화면에는 이 값을 그대로 보여준다.
  final String message;

  /// 실제 데이터. 없거나 실패 응답이면 null 이다.
  final T? result;

  /// [parseResult] 는 `result` 가 null 이 아닐 때만 호출된다.
  /// 그래서 호출하는 쪽은 null 검사를 다시 하지 않아도 된다.
  factory CommonResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? value) parseResult,
  ) {
    final rawResult = json['result'];
    return CommonResponse<T>(
      isSuccess: json['isSuccess'] as bool,
      code: json['code'] as String,
      message: json['message'] as String,
      result: rawResult == null ? null : parseResult(rawResult),
    );
  }
}

/// 실패 응답(`DioException`)의 body 를 공통 형식으로 읽는다.
///
/// 오류 body 는 Wrapper 가 아닐 수도 있고(프록시 오류, 타임아웃), 아예 없을
/// 수도 있다. 그런 경우 null 을 돌려주고 호출한 쪽이 기본 문구를 쓴다.
CommonResponse<Object?>? commonErrorOf(Object? data) {
  if (data is! Map<String, dynamic>) return null;
  // 공통 형식이 아닌 Map(v5 의 {message, error, statusCode} 등)이면 캐스팅이
  // 실패한다. 그것도 "공통 응답이 아니다" 와 같은 뜻이므로 null 로 본다.
  try {
    return CommonResponse<Object?>.fromJson(data, (value) => value);
  } on TypeError {
    return null;
  }
}

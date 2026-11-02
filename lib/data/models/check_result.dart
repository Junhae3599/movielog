// lib/data/models/check_result.dart

/// 닉네임·이메일 중복 확인 응답을 담는 DTO.
///
/// v5 는 공통 응답 Wrapper 가 없어서 `{"available": true}` 가 그대로 내려온다.
/// 그래서 `response.data` 를 바로 [CheckResult.fromJson] 에 넘긴다.
/// (`isSuccess`/`code`/`result` Wrapper 는 v6 부터 등장하므로 그때 파싱이 바뀐다)
class CheckResult {
  const CheckResult({required this.available});

  /// true 면 아직 아무도 쓰지 않는 값, false 면 이미 사용 중인 값이다.
  final bool available;

  factory CheckResult.fromJson(Map<String, dynamic> json) {
    return CheckResult(available: json['available'] as bool);
  }
}

// lib/view_models/submit_status.dart

/// 쓰기 요청(회원가입·평점 등록) 한 건의 진행 상태.
///
/// 회원가입 화면과 영화 상세 화면이 같은 네 상태를 쓰므로 한곳에 둔다.
/// 화면은 이 값으로 버튼 잠금·인디케이터·이탈 방지를 모두 판단한다.
enum SubmitStatus { idle, submitting, success, error }

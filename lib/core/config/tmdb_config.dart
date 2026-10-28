// lib/core/config/tmdb_config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// .env 에서 TMDB 설정을 읽는 한 곳.
///
/// 여러 파일에서 'TMDB_ACCESS_TOKEN' 이라는 키 문자열을 반복하지 않도록 모아 두었다.
/// Token 을 소스 코드에 하드코딩하면 GitHub·로그·화면 녹화에 그대로 노출된다.
///
/// 다만 Flutter asset 에 포함된 값은 배포 앱에서 완전한 비밀이 되지 않는다.
/// 실제 운영 서비스라면 백엔드 Proxy 를 두고 Token 을 서버에만 두어야 한다.
abstract final class TmdbConfig {
  static String get accessToken => dotenv.env['TMDB_ACCESS_TOKEN'] ?? '';

  /// Token 이 비어 있으면 TMDB 는 401 을 돌려준다.
  /// 어디서 잘못됐는지 빨리 알 수 있도록 화면에서 미리 확인할 때 쓴다.
  static bool get hasAccessToken => accessToken.isNotEmpty;
}

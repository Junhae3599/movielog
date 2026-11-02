// 테스트 공용 헬퍼
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// SharedPreferencesAsync 를 기기 저장소 대신 메모리로 바꾼다.
/// 테스트마다 호출해 이전 테스트의 값이 남지 않게 한다.
void useInMemoryPreferences({Map<String, Object>? initial}) {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData(initial ?? {});
}

/// 목록 화면의 Loading(기본 900ms)이 끝날 때까지 기다린다.
const loadingDelay = Duration(seconds: 2);

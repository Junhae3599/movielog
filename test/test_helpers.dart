// 테스트 공용 헬퍼
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:movielog/data/services/tmdb_movie_service.dart';

/// SharedPreferencesAsync 를 기기 저장소 대신 메모리로 바꾼다.
/// 테스트마다 호출해 이전 테스트의 값이 남지 않게 한다.
void useInMemoryPreferences({Map<String, Object>? initial}) {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData(initial ?? {});
}

/// Loading 이 끝날 때까지 기다리는 여유 시간.
const loadingDelay = Duration(seconds: 2);

/// 앱 최상단의 MultiProvider 를 테스트에서도 같은 모양으로 올린다.
///
/// Route 안의 ChangeNotifierProvider 가 `context.read<TmdbMovieService>()` 로
/// 공용 Service 를 찾기 때문에, 이것 없이 Router 를 띄우면 오류가 난다.
Widget withServices(TmdbMovieService service, {required Widget child}) {
  return MultiProvider(
    providers: [Provider<TmdbMovieService>.value(value: service)],
    child: child,
  );
}

# MovieLog

영화를 기록하는 Flutter 앱. UMC 11th 워크북 과제 프로젝트입니다.

영화 원본 정보(제목·포스터·장르·`movieId`)는 **TMDB** 가 담당하고,
회원·평점·즐겨찾기는 **MovieLog 자체 백엔드**가 담당합니다.

## 시작하기

```bash
# 1) TMDB Read Access Token 넣기
cp .env.example .env
#   .env 를 열어 TMDB_ACCESS_TOKEN= 뒤에 발급받은 Token 을 붙여넣습니다.
#   (짧은 API Key 가 아니라 긴 문자열인 API Read Access Token 입니다)

# 2) 실행
flutter pub get
flutter run
```

`.env` 는 `.gitignore` 에 등록되어 커밋되지 않습니다.
Token 을 캡처·커밋 메시지·채팅에 그대로 붙여넣지 않습니다. 노출됐다면 폐기하고 새로 발급합니다.

> Flutter asset 에 포함된 값은 배포 앱에서 완전한 비밀로 보호되지 않습니다.
> 실제 운영 서비스에서는 백엔드 Proxy 를 두고 Token 을 서버에만 보관해야 합니다.

## 구조 — UI Layer 와 Data Layer 분리

```
lib/
├─ main.dart                      — .env 로드 후 runApp
├─ movie_log_app.dart             — MultiProvider + MaterialApp.router
├─ router/app_router.dart         — Route 마다 ChangeNotifierProvider 로 ViewModel 생성
│
├─ core/                          [Data Layer] 앱 전역 설정
│  ├─ config/tmdb_config.dart            — .env 에서 Token 을 읽는 한 곳
│  └─ network/
│     ├─ tmdb_client.dart                — TMDB 전용 Dio Client
│     └─ tmdb_logging_interceptor.dart   — 요청·응답·오류 로그 (Token 은 마스킹)
│
├─ data/                          [Data Layer]
│  ├─ models/                            — TMDB 응답 DTO
│  │  ├─ tmdb_movie_dto.dart
│  │  ├─ tmdb_movie_page_dto.dart
│  │  └─ tmdb_genre_dto.dart
│  ├─ services/tmdb_movie_service.dart   — HTTP 요청과 DTO 변환만 담당
│  └─ preferences/genre_preference.dart  — 마지막으로 고른 장르 ID 저장
│
├─ view_models/                   [UI Layer] 화면(페이지)마다 하나
│  ├─ movie_home_view_model.dart         — 인기 영화 5개
│  └─ movie_list_view_model.dart         — 최대 30개 수집, 장르 필터
│
├─ screens/                       [UI Layer] View
└─ widgets/                       [UI Layer] 공통 Widget (TmdbPosterImage 등)
```

### 책임 분리

| 계층 | 하는 일 | 하지 않는 일 |
| --- | --- | --- |
| View (screens, widgets) | 상태를 읽어 그리고, 입력을 ViewModel 에 전달 | API 호출, JSON 파싱 |
| ViewModel | Loading/Empty/Error/Success 관리, **화면 정책**(5개·30개·선택 장르) | HTTP, DTO 변환 |
| Service | HTTP 요청, 응답 JSON → DTO | 개수 제한, 필터링 |
| Model (DTO) | 값만 담는다 | 자신이 어떻게 그려지는지 모른다 |

`TmdbMovieService` 는 상태를 갖지 않으므로(stateless) 여러 ViewModel 이
`MultiProvider` 에 등록된 **같은 인스턴스 하나**를 공유합니다.
화면별 ViewModel 은 각 Route 안의 `ChangeNotifierProvider` 가 만들고 dispose 까지 맡습니다.

> `MultiProvider` 는 `MaterialApp.router` 를 감싸는 최상단에 두어야 합니다.
> GoRouter 는 화면을 옮길 때마다 그 Route 의 Widget Tree 를 새로 만들기 때문에,
> Provider 가 특정 화면 하위에만 있으면 다른 Route 로 이동한 화면은
> `context.read` 로 그 Provider 를 찾지 못하고 오류가 납니다.

### context.watch 와 Consumer

화면 전체가 아니라 목록 영역만 다시 그리면 되므로 이 프로젝트는 `Consumer` 를 씁니다.
`context.watch` 는 호출한 Widget 의 `build()` 전체를 다시 실행하지만,
`Consumer` 는 자신의 `builder` 범위만 다시 실행합니다.
버튼 탭·재시도처럼 한 번만 메서드를 부를 때는 `context.read` 를 씁니다.

## 사용하는 TMDB API

| 용도 | Method | URL | 주요 Query |
| --- | --- | --- | --- |
| 인기 영화 | GET | `/movie/popular` | `language=ko-KR`, `page` |
| 영화 탐색 | GET | `/discover/movie` | `language`, `page`, `sort_by=popularity.desc`, `include_adult=false`, `include_video=false`, `with_genres` |
| 장르 목록 | GET | `/genre/movie/list` | `language=ko` |

포스터는 `poster_path` 가 파일 경로만 내려오므로
`https://image.tmdb.org/t/p/w500` + `poster_path` 로 조합합니다. (`TmdbPosterImage`)

## 화면 정책

- **홈** — Popular 첫 페이지 결과의 **앞 5개**. `take(5)` 를 쓰므로 5개보다 적게 와도
  범위 오류가 나지 않습니다. 추천 카드 1개 + Grid 4개로 보여줍니다.
- **영화 목록** — Discover 를 page 1 부터 호출하며 **TMDB `id` 기준으로 중복을 제거**해
  최대 30개를 모읍니다. 한 페이지의 개수(TMDB 는 20개)를 하드코딩하지 않고,
  30개가 되거나 `page >= total_pages` 가 될 때까지 요청합니다.
- **장르** — Genre API 결과로 Chip 과 BottomSheet 를 채웁니다. 장르를 고르면
  이미 받아 둔 30개를 로컬에서 거르지 않고 `with_genres` 로 **page 1 부터 다시 조회**합니다.
  "전체" 는 `with_genres` 를 보내지 않습니다. 요청 중에는 장르를 바꿀 수 없습니다.
- **영화 상세·평점** — 경로에 **TMDB `id`** 가 들어가고, 이 값이 6주차에
  자체 백엔드의 `movieId` 가 됩니다. 배열 index 를 쓰면 정렬·필터가 바뀔 때
  다른 영화를 가리키게 됩니다.

## 검증 (2026-10-28)

```
flutter analyze              → No issues found!
flutter test                 → All tests passed! (55개, live 1건 skip)
flutter test --tags live --run-skipped
                             → All tests passed! (6개, 실제 TMDB 호출)
flutter build web --debug    → ✓ Built build/web
```

### 실제 TMDB 호출 결과

`test/tmdb_live_test.dart` 가 실제 서버를 불러 확인한 내용입니다.

```
[TMDB 요청 Header] {Authorization: Bearer ***, accept: application/json}   ← Token 마스킹

[TMDB 응답] 200 .../movie/popular?language=ko-KR&page=1
[Popular] total_pages=1001 results=20 → 인기 5개
  id=969681  스파이더맨: 브랜드 뉴 데이  (poster=true) genreIds=[878, 28, 12]
  id=1058424 호프                      (poster=true) genreIds=[878, 9648, 28]
  id=1101412 폴2: 데드포인트            (poster=true) genreIds=[53]

[TMDB 응답] 200 .../genre/movie/list?language=ko
[Genre] 19개   12 모험 / 16 애니메이션 / 35 코미디 / 80 범죄 / 99 다큐멘터리 ...

[TMDB 응답] 200 .../discover/movie?...&page=1
[TMDB 응답] 200 .../discover/movie?...&page=2
[Discover 전체] 30개 (고유 id 30개)        ← 하드코딩 없이 2페이지를 모아 30개

[TMDB 응답] 200 .../discover/movie?...&page=1&with_genres=878
[TMDB 응답] 200 .../discover/movie?...&page=2&with_genres=878
[Discover with_genres=878] 30개, 전체 목록과 겹치는 영화 8개
  ← 로컬 where 필터가 아니라 Query 에 with_genres 가 실려 나간 재조회
  ← 결과 30개 전부 genreIds 에 878 을 포함

"전체" 선택 → with_genres 가 Query 에서 빠진 요청으로 다시 조회
```

#### 요청 실패 재현 (Challenge)

`.env` 의 Token 을 일부러 잘못된 값으로 바꾸고 호출한 로그입니다.

```
[TMDB 요청 Header] {Authorization: Bearer ***, accept: application/json}   ← 오류 경로에서도 마스킹
[TMDB 오류] https://api.themoviedb.org/3/movie/popular?language=ko-KR&page=1
[TMDB 오류 status] 401
[TMDB 오류 내용] ... the response has a status code of 401 ...
```

이때 화면에는 "TMDB 인증에 실패했어요. Token 설정을 확인해 주세요." 가 표시됩니다.
`kDebugMode` 가 false 인 release 빌드에서는 Interceptor 를 달지 않으므로 이 로그가 출력되지 않습니다.

| 테스트 파일 | 확인하는 것 |
| --- | --- |
| `test/tmdb_dto_test.dart` | snake_case↔camelCase 연결, null·누락 값, 정수→double 변환, release_date 없을 때 |
| `test/movie_home_view_model_test.dart` | 인기 5개 추출, 5개보다 적을 때, empty/error, 중복 요청 방지 |
| `test/movie_list_view_model_test.dart` | 30개 수집(2페이지), id 기준 중복 제거, 30개 미만도 정상, `with_genres` page 1 재조회, "전체"는 미전송, 요청 중 장르 변경 차단, 장르 저장·복원, 401 구분, 실패 시 목록 유지 |
| `test/async_movie_list_test.dart` | Loading/Empty/Error/Success 화면, 재시도, Chip 재조회, 재시도 Dialog |
| `test/router_test.dart` | 화면 전환, 홈 인기 5개, 상세 경로에 TMDB id 전달 |
| `test/interaction_test.dart` | 평점 Dialog, 즐겨찾기 Snackbar, BottomSheet 가 Genre API 결과로 채워짐 |
| `test/tmdb_live_test.dart` | **실제 TMDB 호출.** Token 로드, Popular/Genre/Discover 200, 30개 수집, `with_genres` 재조회 |

`tmdb_live_test.dart` 를 뺀 나머지는 `test/fakes/fake_tmdb_movie_service.dart` 로 TMDB 를 대신합니다.
UI Layer 는 Data Layer 가 돌려주는 DTO 타입만 알면 되므로, Token 이 없거나
TMDB 가 점검 중이어도 이 테스트들은 그대로 돌아갑니다.

실제 서버를 부르는 `tmdb_live_test.dart` 는 `dart_test.yaml` 의 tag 설정으로
기본 실행에서 건너뜁니다. 확인할 때만 다음으로 실행합니다.

```bash
flutter test --tags live --run-skipped
```

## Challenge Mission 구현 상태

- **Pull to Refresh** — `RefreshIndicator`. 현재 선택된 장르를 유지한 채 page 1 부터 다시 호출하고,
  새로고침 중에는 기존 목록을 화면에서 지우지 않습니다. Loading 중에는 제스처가 동작하지 않습니다.
- **장르 다중 선택** — BottomSheet 에서 여러 장르를 고르면 선택된 id 를 OR(`|`)로 연결해
  `with_genres` 에 넘깁니다. 선택이 없는 상태로 확인하면 `with_genres` 없이 전체를 불러옵니다.
- **요청 실패 재시도 Dialog** — 최근에 성공한 목록이 있으면 비우지 않고
  `MovieListRetryDialog` 로 재시도/취소를 묻습니다. 재시도는 마지막 장르 조건으로 page 1 부터 다시 실행합니다.

## 트러블슈팅

### No.1 — 장르를 빠르게 바꾸면 다른 장르의 목록이 표시된다

**이슈** Chip 을 연속으로 누르면 나중에 고른 장르의 목록이 아니라 먼저 고른 장르의 목록이 남는다.

**문제** 먼저 보낸 요청의 응답이 나중에 도착하면, 이미 바뀐 상태를 그 늦은 응답이 덮어쓴다.

**해결** `_requestVersion` 을 두고 요청 시작마다 올린다. 응답이 돌아왔을 때 버전이 다르면
그 결과를 버린다(`_isStale`). 거기에 요청 중에는 Chip 을 비활성화(`isBusy`)해 애초에
중복 요청이 생기지 않게 했다.

### No.2 — 요청 중인데도 장르 선택이 한 번 더 들어간다

**이슈** `isBusy` 로 막았는데도 테스트에서 두 번째 장르 선택이 통과했다.

**문제** `selectGenres()` 가 `_genrePreference.save()` 를 `await` 하는 동안에는
아직 `status` 가 `loading` 이 아니어서 `isBusy` 가 false 였다. 첫 `await` 까지의
짧은 구간이 그대로 열려 있었다.

**해결** 저장을 기다리기 **전에** `status = loading` + `notifyListeners()` 를 먼저 실행해
동기 구간에서 바로 busy 가 되게 했다. (`test/movie_list_view_model_test.dart`
"요청 중에는 장르를 바꾸지 못한다" 가 이 회귀를 잡는다)

### No.3 — Token 이 비어 있을 때 원인을 알기 어렵다

**이슈** `.env` 에 Token 을 넣지 않으면 화면에 "불러오지 못했어요" 만 뜬다.

**문제** 네트워크 실패와 인증 실패(401)가 같은 문구로 묶여 있었다.

**해결** ViewModel 이 `DioException.response?.statusCode == 401` 을 구분해
"TMDB 인증에 실패했어요. Token 설정을 확인해 주세요." 를 보여준다.
Interceptor 로그에도 status 가 함께 남아 401 을 바로 확인할 수 있다.
(로그의 `Authorization` 은 `Bearer ***` 로 마스킹된다)

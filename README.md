# MovieLog

영화를 기록하는 Flutter 앱. UMC 11th 워크북 과제 프로젝트입니다.

영화 원본 정보(제목·포스터·장르·`movieId`)는 **TMDB** 가 담당하고,
회원·평점·즐겨찾기는 **MovieLog 자체 백엔드**가 담당합니다.
두 서버는 baseUrl 과 인증 방식이 다르므로 Dio Client 를 끝까지 분리합니다.

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
│     ├─ movie_log_client.dart           — 자체 백엔드 전용 Dio Client (6주차)
│     └─ api_logging_interceptor.dart    — 요청·응답·오류 로그 (Token 은 마스킹)
│
├─ data/                          [Data Layer]
│  ├─ models/
│  │  ├─ tmdb_movie_dto.dart             — TMDB 응답 DTO
│  │  ├─ tmdb_movie_page_dto.dart
│  │  ├─ tmdb_genre_dto.dart
│  │  ├─ check_result.dart               — {"available": bool}        (6주차)
│  │  ├─ rating_dto.dart                 — 평점 한 건                  (6주차)
│  │  └─ rating_with_movie.dart          — 평점 + TMDB 영화 한 쌍       (6주차)
│  ├─ services/
│  │  ├─ tmdb_movie_service.dart         — HTTP 요청과 DTO 변환만 담당
│  │  ├─ member_check_service.dart       — 닉네임·이메일 중복 확인      (6주차)
│  │  └─ rating_api_service.dart         — 유저별 평점 조회            (6주차)
│  └─ preferences/genre_preference.dart  — 마지막으로 고른 장르 ID 저장
│
├─ view_models/                   [UI Layer] 화면(페이지)마다 하나
│  ├─ movie_home_view_model.dart         — 인기 영화 5개
│  ├─ movie_list_view_model.dart         — 최대 30개 수집, 장르 필터
│  ├─ sign_up_view_model.dart            — 중복 확인 상태              (6주차)
│  └─ my_ratings_view_model.dart         — 평점 + 영화 정보 묶기        (6주차)
│
├─ screens/                       [UI Layer] View
│  └─ my_ratings/                        — 내가 등록한 평점 화면        (6주차)
└─ widgets/                       [UI Layer] 공통 Widget
   ├─ tmdb_poster_image.dart
   ├─ movie_log_text_form_field.dart     — errorText·오른쪽 버튼 자리를 받는다
   └─ movie_log_button.dart              — 기본·통신 중·비활성 버튼     (6주차)
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
| 영화 상세 | GET | `/movie/{movie_id}` | `language=ko-KR` |

포스터는 `poster_path` 가 파일 경로만 내려오므로
`https://image.tmdb.org/t/p/w500` + `poster_path` 로 조합합니다. (`TmdbPosterImage`)

## 사용하는 MovieLog 백엔드 API (v5)

baseUrl 은 `https://workbook.devnoco.com` 입니다.

| 용도 | Method | URL | 성공 응답 |
| --- | --- | --- | --- |
| 닉네임 중복 확인 | GET | `/v5/members/nickname/{nickname}` | `{"available": true}` |
| 이메일 중복 확인 | GET | `/v5/members/email/{email}` | `{"available": true}` |
| 유저별 평점 조회 | GET | `/v5/members/{memberId}/ratings` | 평점 배열 (없으면 `[]`) |

v5 는 **공통 응답 Wrapper 가 없습니다.** 성공은 결과값을 그대로 돌려주고, 실패만
`{message, error, statusCode}` 로 내려옵니다. 그래서 `response.data` 를 바로
`fromJson` 에 넘깁니다. (`isSuccess`/`code`/`result` Wrapper 는 v6 부터입니다)

회원가입 POST 와 평점 등록·수정·삭제는 v6 부터이므로, 이번 주차에는 계정을 만들거나
평점을 저장하는 요청을 보내지 않습니다.

## 화면 정책

- **홈** — Popular 첫 페이지 결과의 **앞 5개**. `take(5)` 를 쓰므로 5개보다 적게 와도
  범위 오류가 나지 않습니다. 추천 카드 1개 + Grid 4개로 보여줍니다.
- **영화 목록** — Discover 를 page 1 부터 호출하며 **TMDB `id` 기준으로 중복을 제거**해
  최대 30개를 모읍니다. 한 페이지의 개수(TMDB 는 20개)를 하드코딩하지 않고,
  30개가 되거나 `page >= total_pages` 가 될 때까지 요청합니다.
- **장르** — Genre API 결과로 Chip 과 BottomSheet 를 채웁니다. 장르를 고르면
  이미 받아 둔 30개를 로컬에서 거르지 않고 `with_genres` 로 **page 1 부터 다시 조회**합니다.
  "전체" 는 `with_genres` 를 보내지 않습니다. 요청 중에는 장르를 바꿀 수 없습니다.
- **영화 상세·평점** — 경로에 **TMDB `id`** 가 들어가고, 이 값이 자체 백엔드의
  `movieId` 입니다. 배열 index 를 쓰면 정렬·필터가 바뀔 때 다른 영화를 가리키게 됩니다.
- **회원가입 중복 확인** — 닉네임·이메일 입력창 **바깥 오른쪽**에 `MovieLogButton` 을
  8px 간격으로 두고, 결과를 입력창의 `errorText` 에 연결합니다. 두 필드는 상태를
  합치지 않고 각각(`nicknameCheckStatus` / `emailCheckStatus`) 관리합니다.
  입력이 바뀌면 이전 결과를 `idle` 로 무효화하고, 기다리던 응답은 버립니다.
  통신 실패(`DioException`)와 정상 중복 응답(`available: false`)은 다른 문구입니다.
- **내가 등록한 평점** — 마이페이지에서 `context.push('/my/ratings')` 로 열리는
  자식 화면입니다. 조회 대상은 **학습용 상수 `sampleMemberId = 1`** 이며 화면에
  입력창을 두지 않습니다. (로그인 전이므로 '현재 로그인 사용자' 가 아닙니다.
  그래서 다른 사람의 기록을 고치는 수정·삭제 버튼도 두지 않습니다)
  빈 배열은 Empty, `DioException` 만 Error 로 구분합니다.
- **두 서버를 한 화면에서** — 평점의 주인은 자체 백엔드이므로 TMDB 영화 조회가
  실패해도 평점 목록을 지우지 않고 제목·포스터만 placeholder 로 보여줍니다.
  같은 `movieId` 는 한 번만 조회해 캐시하고, 404(없는 영화)는 null 로 캐시하지만
  일시적인 네트워크 실패는 캐시하지 않아 다음 로딩에서 다시 시도합니다.

## 공용 버튼의 상태와 너비

`MovieLogButton` 하나가 기본 · 통신 중 · 비활성 세 상태를 모두 표현합니다.
화면은 "지금 통신 중인지, 지금 누를 수 있는지" 만 전달하고, 버튼은 **상태를 표시만
하고 스스로 바꾸지 않습니다.** 통신 중에는 `label` 대신 인디케이터만 그립니다.

`width` 에 넘기는 값에 따라 가로 공간을 정하는 방식이 달라집니다.

```
null            → 내용 기반 크기 (좁은 자리: 입력창 옆 중복 확인 버튼)
double.infinity → 부모가 허용하는 최대 너비 (넓은 자리: Form 아래 가입하기 버튼)
고정 값          → 항상 같은 크기 (평점 화면의 '다시 시도' 버튼, 160)
```

> `double.infinity` 는 가로 제약이 없는 `Row` 안에서는 쓸 수 없습니다.
> 또 이 프로젝트 Theme 의 `ElevatedButton` 은 `minimumSize` 가 `(infinity, 56)` 이므로,
> `MovieLogButton` 은 `minimumSize: Size.zero` 로 덮어써서 `width: null` 이 실제로
> 내용 기반 크기가 되게 합니다. 크기는 바깥 `SizedBox` 가 정합니다.

입력창 옆에 둘 때는 `MovieLogTextFormField.inputHeight` 를 높이로 넘겨 입력창과
같은 높이를 씁니다. 오류 문구가 붙어 입력창이 길어져도 버튼은 첫 줄 높이에 머뭅니다.

## 검증 (2026-11-02)

```
flutter analyze              → No issues found!
flutter test                 → All tests passed! (100개, live 2건 skip)
flutter test --tags live --run-skipped
                             → All tests passed! (13개, 실제 TMDB·MovieLog 호출)
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

### 실제 MovieLog 백엔드(v5) 호출 결과

`test/movie_log_live_test.dart` 가 실제 서버를 불러 확인한 내용입니다.

```
[MovieLog 응답] 200 .../v5/members/nickname/%EB%AC%B4%EB%B9%84%EB%9F%AC%EB%B2%84
[MovieLog 응답 Body] {available: true}          ← 닉네임은 경로에 들어가므로 인코딩

[MovieLog 응답] 200 .../v5/members/email/movie%40example.com
[MovieLog 응답 Body] {available: true}

[MovieLog 응답] 200 .../v5/members/1/ratings
[MovieLog 응답 Body] [
  {ratingId: 3, movieId: 13,  score: 3, comment: null,        createdAt: 2026-11-01T19:00:27.956Z},
  {ratingId: 2, movieId: 680, score: 4, comment: 다시 봐도 좋다, createdAt: ...},
  {ratingId: 1, movieId: 550, score: 5, comment: 최고의 영화!,   createdAt: ...}]
                                                ← comment 가 null 인 평점이 실제로 온다

[TMDB 응답] 200 .../movie/13?language=ko-KR     ← 평점의 movieId 로 영화 정보를
[TMDB 응답] 200 .../movie/680?language=ko-KR       한 편씩 조회해 한 쌍으로 묶는다
[TMDB 응답] 200 .../movie/550?language=ko-KR
```

실패 응답도 같은 테스트에서 확인했습니다. v5 는 실패만 공통 형식으로 내려줍니다.

```
[MovieLog 오류] .../v5/members/99999/ratings
[MovieLog 오류 status] 404
[MovieLog 오류 Body] {message: 존재하지 않는 유저입니다., error: Not Found, statusCode: 404}
                                                → 화면 문구 "존재하지 않는 회원입니다."

[MovieLog 오류] .../v5/members/abc/ratings
[MovieLog 오류 status] 400
[MovieLog 오류 Body] {message: Validation failed (numeric string is expected), ...}
                                                → 화면 문구 "memberId 형식을 다시 확인해 주세요."
```

> v5 에는 회원가입 POST 가 없어 **실제 서버에서 `available: false` 를 만들 수는
> 없습니다.** 그래서 중복 응답 경로는 `test/fakes/fake_member_check_service.dart` 로
> 검증했습니다. (실호출로 확인한 것은 200 응답과 `available` 파싱까지입니다)

| 테스트 파일 | 확인하는 것 |
| --- | --- |
| `test/tmdb_dto_test.dart` | snake_case↔camelCase 연결, null·누락 값, 정수→double 변환, release_date 없을 때 |
| `test/movie_home_view_model_test.dart` | 인기 5개 추출, 5개보다 적을 때, empty/error, 중복 요청 방지 |
| `test/movie_list_view_model_test.dart` | 30개 수집(2페이지), id 기준 중복 제거, 30개 미만도 정상, `with_genres` page 1 재조회, "전체"는 미전송, 요청 중 장르 변경 차단, 장르 저장·복원, 401 구분, 실패 시 목록 유지 |
| `test/async_movie_list_test.dart` | Loading/Empty/Error/Success 화면, 재시도, Chip 재조회, 재시도 Dialog |
| `test/router_test.dart` | 화면 전환, 홈 인기 5개, 상세 경로에 TMDB id 전달 |
| `test/interaction_test.dart` | 평점 Dialog, 즐겨찾기 Snackbar, BottomSheet 가 Genre API 결과로 채워짐 |
| `test/movie_log_dto_test.dart` | `available` 파싱, 평점 DTO 의 모든 key, `comment: null`, 소수로 온 score |
| `test/sign_up_view_model_test.dart` | 중복 확인 5가지 상태, 통신 실패와 중복 구분, 입력 변경 시 무효화, 중복 값 재입력 시 재요청 없음, 공백 차이, 늦은 응답 무시, 두 필드 독립, dispose |
| `test/sign_up_check_test.dart` | 확인 전/통신 중/사용 가능/중복 화면, `errorText` 연결, 입력 변경 무효화, `MovieLogButton` 너비·높이 |
| `test/my_ratings_view_model_test.dart` | memberId 1 조회, Loading/Empty/Error/Success, 400·404·네트워크 문구 구분, movieId 캐시, TMDB 실패 시 목록 유지 |
| `test/my_ratings_screen_test.dart` | 마이페이지 → 자식 화면 진입·복귀, NavigationBar 없음, 네 상태 화면, 재시도, placeholder |
| `test/tmdb_live_test.dart` | **실제 TMDB 호출.** Token 로드, Popular/Genre/Discover 200, 30개 수집, `with_genres` 재조회 |
| `test/movie_log_live_test.dart` | **실제 MovieLog 백엔드 호출.** 중복 확인 200, memberId 1 평점 조회, 404·400 문구, 평점+TMDB 묶기 |

`*_live_test.dart` 를 뺀 나머지는 `test/fakes/` 의 Fake Service 로 두 서버를 대신합니다.
UI Layer 는 Data Layer 가 돌려주는 DTO 타입만 알면 되므로, Token 이 없거나
서버가 점검 중이어도 이 테스트들은 그대로 돌아갑니다.

실제 서버를 부르는 `tmdb_live_test.dart` 와 `movie_log_live_test.dart` 는
`dart_test.yaml` 의 tag 설정으로 기본 실행에서 건너뜁니다. 확인할 때만 다음으로 실행합니다.

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
- **중복 값은 바꾸기 전까지 다시 묻지 않기 (6주차)** — "마지막으로 확인한 값" 과
  **"마지막으로 중복이었던 값"** 을 따로 기억합니다. 중복 응답을 받으면 즉시 버튼이
  비활성화되고, 값을 다른 문자열로 고치는 동안에는 Form 이 원래 상태로 돌아옵니다.
  고친 값이 방금 지운 값과 정확히 같으면 **서버에 다시 묻지 않고** 바로 에러 상태로
  돌아갑니다. 비교는 `trim()` 한 값으로 하므로 앞뒤 공백 차이에 속지 않습니다.

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

### No.4 — 회원가입 화면 테스트가 ProviderNotFoundException 으로 깨진다

**이슈** 중복 확인을 붙인 뒤 `widget_test.dart` 의 회원가입 테스트 6건이
`Could not find the correct Provider<SignUpViewModel>` 로 실패했다.

**문제** 앱에서는 `/sign-up` Route 의 `ChangeNotifierProvider` 가 ViewModel 을 만드는데,
테스트는 `SignUpScreen` 만 `MaterialApp(home:)` 으로 직접 띄우고 있었다.
Provider 는 범위(scope)를 갖기 때문에 화면만 따로 올리면 찾을 수 없다.

**해결** `test_helpers.dart` 에 `signUpScreen()` 을 두고, Route 가 하는 것과 같은 모양으로
ViewModel 을 함께 올리게 했다. Fake Service 를 기본값으로 두어 기존 테스트는 인자 없이 쓴다.

### No.5 — 통신 중인 버튼을 글자로 찾을 수 없다

**이슈** "통신 중에는 버튼이 비활성화된다" 테스트에서 `isLoading` 이 계속 false 로 나왔다.

**문제** `find.widgetWithText(MovieLogButton, '중복 확인')` 으로 찾고 있었는데,
통신 중에는 `label` Text 대신 `CircularProgressIndicator` 만 그린다. 그래서 그 Finder 가
닉네임 버튼을 건너뛰고 아직 글자가 남아 있는 **이메일 버튼**을 집었다.

**해결** 상태에 따라 사라지는 글자 대신 `find.byType(MovieLogButton).at(0/1/2)` 로 찾는다.
(글자가 사라지는 것 자체는 "통신 중에는 둘 중 하나만 그린다" 는 의도된 동작이다)

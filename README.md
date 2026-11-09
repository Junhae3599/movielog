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

평점 쓰기(등록·수정·삭제)는 **앱에서 학습용 회원가입을 마친 뒤** 열립니다. 가입 결과의
memberId 를 메모리에만 보관하므로 앱을 다시 시작하면 가입 화면부터 다시 시작합니다.
(아직 로그인이 없습니다. memberId 를 안다는 것은 인증이 아니며, 다음 주차에 JWT 로
바뀝니다)

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
│  │  ├─ rating_with_movie.dart          — 평점 + TMDB 영화 한 쌍       (6주차)
│  │  ├─ common_response.dart            — v6 공통 응답 Wrapper<T>     (7주차)
│  │  ├─ create_member_request.dart      — 회원가입 요청 body          (7주차)
│  │  ├─ sign_up_models.dart             — 가입 성공 result            (7주차)
│  │  └─ rating_request.dart             — 평점 등록·수정 요청 body     (7주차)
│  ├─ services/
│  │  ├─ tmdb_movie_service.dart         — HTTP 요청과 DTO 변환만 담당
│  │  ├─ sign_up_service.dart            — 중복 확인 + 회원가입 POST    (7주차)
│  │  └─ rating_api_service.dart         — 평점 조회·등록·수정·삭제     (7주차)
│  └─ preferences/genre_preference.dart  — 마지막으로 고른 장르 ID 저장
│
├─ view_models/                   [UI Layer] 화면(페이지)마다 하나
│  ├─ movie_home_view_model.dart         — 인기 영화 5개
│  ├─ movie_list_view_model.dart         — 최대 30개 수집, 장르 필터
│  ├─ sign_up_view_model.dart            — 중복 확인 + 회원가입 제출     (7주차)
│  ├─ movie_detail_view_model.dart       — 평점 등록                   (7주차)
│  ├─ my_ratings_view_model.dart         — 평점 조회·수정·삭제          (7주차)
│  ├─ learning_member_session.dart       — 가입 결과 memberId (앱 전역)  (7주차)
│  └─ submit_status.dart                 — idle/submitting/success/error
│
├─ screens/                       [UI Layer] View
│  ├─ movie_detail/
│  │  ├─ movie_detail_loader.dart        — extra 가 없으면 TMDB 재조회   (7주차)
│  │  └─ movie_detail_screen.dart        — 평점 등록
│  └─ my_ratings/                        — 조회·수정·삭제·다중 삭제      (7주차)
└─ widgets/                       [UI Layer] 공통 Widget
   ├─ tmdb_poster_image.dart
   ├─ movie_log_text_form_field.dart     — errorText·오른쪽 버튼 자리를 받는다
   ├─ movie_log_button.dart              — 기본·통신 중·비활성 버튼     (6주차)
   ├─ movie_rating_input.dart            — 1~5 정수 별점                (7주차)
   ├─ rating_dialog.dart                 — 별점 + 코멘트 입력 Dialog     (7주차)
   └─ loading_overlay.dart               — 화면 위 진행 오버레이         (7주차)
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

## 사용하는 MovieLog 백엔드 API (v6)

baseUrl 은 `https://workbook.devnoco.com` 입니다. 7주차에 경로를 `v5` → `v6` 으로
올리고 쓰기 API 네 개를 더했습니다.

| 용도 | Method | URL | 성공 응답 |
| --- | --- | --- | --- |
| 닉네임 중복 확인 | GET | `/v6/members/nickname/{nickname}` | 200 + `{"available": true}` |
| 이메일 중복 확인 | GET | `/v6/members/email/{email}` | 200 + `{"available": true}` |
| 회원가입 | POST | `/v6/members` | 201 + 공통 응답(`result` = 회원 정보) |
| 유저별 평점 조회 | GET | `/v6/members/{memberId}/ratings` | 200 + 평점 배열 (없으면 `[]`) |
| 평점 등록 | POST | `/v6/members/{memberId}/ratings` | 201 + 공통 응답 |
| 평점 수정 | PATCH | `/v6/members/{memberId}/ratings/{ratingId}` | 200 + 공통 응답(`result` = null) |
| 평점 삭제 | DELETE | `/v6/members/{memberId}/ratings/{ratingId}` | 204 + 본문 없음 |

**"v6 이면 전부 공통 응답" 이 아닙니다.** 신규 쓰기 API 의 성공과 v6 의 모든 실패는
`{isSuccess, code, message, result}` 로 감싸지지만, v5 때부터 있던 중복 확인과 평점
조회는 성공 시 **직접 객체/배열**을 그대로 돌려줍니다. 그래서 API 마다 성공 계약에
맞춰 파싱합니다. (`CommonResponse<T>` / `CheckResult` / `List<RatingDto>` / 본문 없음)

```
회원가입 201   {isSuccess: true, code: COMMON201, message: 회원가입에 성공했습니다.,
                result: {memberId: 26, email: ..., nickname: ...}}
평점 등록 201  {isSuccess: true, code: COMMON201, message: 평점 등록에 성공했습니다., result: 38}
평점 수정 200  {isSuccess: true, code: COMMON200, message: 평점 수정에 성공했습니다., result: null}
평점 삭제 204  (본문 없음 — response.data as Map 을 부르면 성공인데도 파싱 오류가 난다)
중복 확인 200  {available: true}                      ← Wrapper 없음
평점 조회 200  [{ratingId: 38, movieId: 550, ...}]     ← Wrapper 없음
```

오류 `code` 는 **문구가 아니라 다음 행동**을 정하는 데 씁니다. 같은 `COMMON404` 가
등록에서는 "존재하지 않는 유저입니다.", 수정·삭제에서는 "존재하지 않는 평점입니다."
이기 때문에, 화면 문구는 서버 `message` 를 그대로 쓰고 code 로는 "목록을 다시 읽을지"
만 판단합니다. (`shouldRefreshAfterRatingError` — 403·404 만 재조회)

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
  목록에서 들어오면 영화 DTO 를 `extra` 로 받아 다시 요청하지 않고, URL 로 바로
  들어오면 `MovieDetailLoader` 가 경로의 id 로 TMDB 상세를 한 번 조회합니다.
- **쓰기 권한의 출처** — 평점 쓰기 경로에 들어가는 memberId 는 **회원가입 응답에서
  받은 값**이며 `LearningMemberSession` 이 앱 전역에 보관합니다. 6주차의 고정 상수 1 을
  새 회원의 id 처럼 쓰지 않습니다. 메모리에만 있으므로 앱을 다시 시작하면 사라지고,
  **memberId 를 안다는 것은 인증이 아닙니다.** 가입 전에는 평점 버튼을 잠급니다.
- **회원가입 제출** — 닉네임·이메일 중복 확인이 **모두 `available`** 이어야 가입하기
  버튼이 켜집니다. 확인 직후에도 다른 사용자가 같은 값을 등록할 수 있으므로
  **POST 의 409 가 최종 중복 결과**입니다. 실패는 목적지로 나눕니다 — 비밀번호 형식
  400 은 입력칸 `errorText`, 그 밖의 400·409 는 화면 Snackbar. 제출 중에는 버튼을
  잠그고 `PopScope` 로 화면 이탈까지 막습니다.
- **평점 입력** — 서버 score 가 1~5 정수라서 3주차의 반 점 입력을 받아 두고 `toInt()`
  로 깎지 않고, `allowHalfRating: false` 로 **입력 단계에서** 막습니다. 별점을 고르기
  전에는 코멘트를 썼더라도 확인 버튼이 켜지지 않습니다. 코멘트는 선택이며 최대 500자,
  비어 있으면 빈 문자열이 아니라 **key 를 생략**해 보냅니다.
- **수정은 comment 를 항상 보냅니다** — PATCH 는 `comment` 를 생략하면 기존 후기를
  null 로 덮습니다. 그래서 `UpdateRatingRequest` 는 유지든 삭제든 의도를 명시해
  score 와 comment 를 **함께** 보냅니다.
- **저장 성공과 재조회 실패는 다른 상태** — 쓰기가 끝나면 목록을 다시 읽습니다. 이때
  GET 만 실패하면 Dialog 는 저장 성공으로 닫고 화면에 "저장은 완료됐지만 목록을
  불러오지 못했습니다" 안내만 띄웁니다. 저장 실패로 되돌리면 사용자가 같은 요청을
  다시 보내 409 를 만나게 됩니다.
- **삭제는 확인 Dialog 를 거칩니다** — 취소하면 요청을 보내지 않습니다. 단일 삭제는
  요청이 끝날 때까지 Dialog 를 유지하고, 다중 삭제는 Dialog 를 먼저 닫고 화면 위
  `LoadingOverlay` 로 진행을 보여줍니다.
- **회원가입 중복 확인** — 닉네임·이메일 입력창 **바깥 오른쪽**에 `MovieLogButton` 을
  8px 간격으로 두고, 결과를 입력창의 `errorText` 에 연결합니다. 두 필드는 상태를
  합치지 않고 각각(`nicknameCheckStatus` / `emailCheckStatus`) 관리합니다.
  입력이 바뀌면 이전 결과를 `idle` 로 무효화하고, 기다리던 응답은 버립니다.
  통신 실패(`DioException`)와 정상 중복 응답(`available: false`)은 다른 문구입니다.
- **내가 등록한 평점** — 마이페이지에서 `context.push('/my/ratings')` 로 열리는
  자식 화면입니다. 조회 대상은 가입 결과를 담아 둔 `LearningMemberSession.memberId`
  이며, 그 값이 없으면 "학습용 회원가입이 필요합니다." 를 보여줍니다.
  빈 배열은 Empty, `DioException` 만 Error 로 구분합니다. 내가 쓴 평점만 보이는
  화면이므로 카드마다 수정·삭제 버튼을 두고, 서버도 남의 평점은 403 으로 막습니다.
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

## 검증 (2026-11-09)

```
flutter analyze              → No issues found!
flutter test                 → All tests passed! (164개, live 2건 skip)
flutter test --tags live --run-skipped
                             → All tests passed! (27개, 실제 TMDB·MovieLog v6 호출)
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

### 실제 MovieLog 백엔드(v6) 호출 결과

`test/movie_log_live_test.dart` 가 실제 서버를 불러 확인한 내용입니다.
이 테스트는 실행할 때마다 **새 학습용 계정**을 만들고(이메일·닉네임에 타임스탬프를
붙입니다), 만든 평점은 같은 실행 안에서 지웁니다. 비밀번호는 로그에 남기지 않습니다.

```
[MovieLog 요청] POST .../v6/members
[MovieLog 응답] 201
[MovieLog 응답 Body] {isSuccess: true, code: COMMON201, message: 회원가입에 성공했습니다.,
                      result: {memberId: 26, email: movielog...@example.com, nickname: mlog313771}}
                                                → 이 memberId 로 이후 평점 경로를 만든다

[MovieLog 요청] POST .../v6/members            ← 같은 값으로 한 번 더
[MovieLog 오류 status] 409
[MovieLog 오류 Body] {isSuccess: false, code: COMMON409, message: 이미 사용 중인 이메일입니다.}
                                                → 최종 중복 결과. 화면은 Snackbar

[MovieLog 요청] POST .../v6/members            ← password: 소문자만
[MovieLog 오류 status] 400
[MovieLog 오류 Body] {isSuccess: false, code: COMMON400,
                      message: 비밀번호는 대문자/소문자/숫자/특수문자를 포함한 8자 이상이어야 합니다.}
                                                → 문구에 "비밀번호" 가 있으므로 입력칸 errorText

[MovieLog 응답] 200 .../v6/members/nickname/mlog313771
[MovieLog 응답 Body] {available: false}         ← 방금 내가 만든 닉네임. Wrapper 없이 온다

[MovieLog 응답] 200 .../v6/members/26/ratings
[MovieLog 응답 Body] []                         ← 새 회원. 빈 배열은 실패가 아니다

[MovieLog 요청] POST .../v6/members/26/ratings  {movieId: 550, score: 5, comment: ...}
[MovieLog 응답] 201
[MovieLog 응답 Body] {isSuccess: true, code: COMMON201, message: 평점 등록에 성공했습니다., result: 38}
[MovieLog 응답] 200 .../v6/members/26/ratings
[MovieLog 응답 Body] [{ratingId: 38, movieId: 550, score: 5, comment: 라이브 테스트 등록, ...}]
                                                → 등록 성공은 GET 으로 다시 확인한다

[MovieLog 요청] POST .../v6/members/26/ratings  ← 같은 영화에 한 번 더
[MovieLog 오류 status] 409
[MovieLog 오류 Body] {code: COMMON409, message: 이미 이 영화에 평점을 남기셨습니다.}
                                                → 재조회 없이 같은 화면에서 안내만

[MovieLog 요청] PATCH .../v6/members/26/ratings/38  {score: 4, comment: 라이브 테스트 수정}
[MovieLog 응답] 200 {isSuccess: true, code: COMMON200, message: 평점 수정에 성공했습니다.,
                     result: null}              ← result 가 없으므로 본문을 파싱하지 않는다
[MovieLog 응답 Body] [{ratingId: 38, score: 4, comment: 라이브 테스트 수정, ...}]
                                                → comment 를 함께 보냈으므로 후기가 유지된다

[MovieLog 요청] PATCH .../v6/members/26/ratings/99999999
[MovieLog 오류] 404 {code: COMMON404, message: 존재하지 않는 평점입니다.}
                                                → 403·404 는 목록을 다시 읽어 서버와 맞춘다

[TMDB 응답] 200 .../movie/550?language=ko-KR    ← 평점의 movieId 로 제목·포스터를 가져와
                                                   "파이트 클럽" 과 한 쌍으로 묶는다

[MovieLog 요청] DELETE .../v6/members/26/ratings/38
[MovieLog 응답] 204
[MovieLog 응답 Body]                            ← 본문이 없다. Map 으로 파싱하지 않는다
[MovieLog 응답] 200 .../v6/members/26/ratings
[MovieLog 응답 Body] []                         → 마지막 항목을 지우면 Empty 화면
```

조회 쪽 실패 문구도 같은 테스트에서 확인했습니다.

```
[MovieLog 오류] .../v6/members/99999999/ratings
[MovieLog 오류 Body] {code: COMMON404, message: 존재하지 않는 유저입니다.}
                                                → 화면 문구 "존재하지 않는 회원입니다."

[MovieLog 오류] .../v6/members/abc/ratings
[MovieLog 오류 Body] {code: COMMON400, message: Validation failed (numeric string is expected)}
                                                → 화면 문구 "memberId 형식을 다시 확인해 주세요."
```

> 실서버에서 만들 수 없는 경로(403 남의 평점, 저장 성공 + GET 실패, 다중 삭제 일부
> 실패)는 `test/fakes/` 의 Fake Service 로 검증했습니다.

| 테스트 파일 | 확인하는 것 |
| --- | --- |
| `test/tmdb_dto_test.dart` | snake_case↔camelCase 연결, null·누락 값, 정수→double 변환, release_date 없을 때 |
| `test/movie_home_view_model_test.dart` | 인기 5개 추출, 5개보다 적을 때, empty/error, 중복 요청 방지 |
| `test/movie_list_view_model_test.dart` | 30개 수집(2페이지), id 기준 중복 제거, 30개 미만도 정상, `with_genres` page 1 재조회, "전체"는 미전송, 요청 중 장르 변경 차단, 장르 저장·복원, 401 구분, 실패 시 목록 유지 |
| `test/async_movie_list_test.dart` | Loading/Empty/Error/Success 화면, 재시도, Chip 재조회, 재시도 Dialog |
| `test/router_test.dart` | 화면 전환, 홈 인기 5개, 상세 경로에 TMDB id 전달 |
| `test/interaction_test.dart` | 평점 Dialog(코멘트·정수 별점·확인 활성화·취소·실패 유지·중복 탭), 즐겨찾기 Snackbar, BottomSheet |
| `test/movie_log_dto_test.dart` | `available` 파싱, 평점 DTO 의 모든 key, `comment: null`, 소수로 온 score, `CommonResponse<T>`, 요청 body 세 개 |
| `test/sign_up_view_model_test.dart` | 중복 확인 5가지 상태, 통신 실패와 중복 구분, 입력 변경 시 무효화, 중복 값 재입력 시 재요청 없음, 공백 차이, 늦은 응답 무시, 두 필드 독립, dispose |
| `test/sign_up_check_test.dart` | 확인 전/통신 중/사용 가능/중복 화면, `errorText` 연결, 입력 변경 무효화, `MovieLogButton` 너비·높이 |
| `test/my_ratings_view_model_test.dart` | 전달받은 memberId 조회, Loading/Empty/Error/Success, 400·404·네트워크 문구 구분, movieId 캐시, TMDB 실패 시 목록 유지 |
| `test/my_ratings_screen_test.dart` | 마이페이지 → 자식 화면 진입·복귀, NavigationBar 없음, 네 상태 화면, 재시도, placeholder |
| `test/sign_up_submit_test.dart` | 가입 성공 → 세션 저장·이동, 400(비밀번호)/400(기타)/409/result 누락 구분, 중복 제출 차단, 제출 중 이탈 방지 |
| `test/movie_detail_view_model_test.dart` | 등록 body 의 movieId·score·comment, 가입 전 차단, 400·404·409 문구, 중복 요청 차단, dispose 뒤 응답 무시 |
| `test/my_ratings_write_test.dart` | 수정·삭제 뒤 재조회, comment 생략 시 null 덮어쓰기, 저장 성공 + GET 실패 분리, 삭제 확인·취소, Empty, 다중 삭제 일부 실패 |
| `test/tmdb_live_test.dart` | **실제 TMDB 호출.** Token 로드, Popular/Genre/Discover 200, 30개 수집, `with_genres` 재조회 |
| `test/movie_log_live_test.dart` | **실제 MovieLog v6 호출.** 회원가입 201·409·400, 중복 확인, 평점 등록→조회→수정→조회→삭제→조회, 404·400 문구 |

`*_live_test.dart` 를 뺀 나머지는 `test/fakes/` 의 Fake Service 로 두 서버를 대신합니다.
`FakeRatingApiService` 는 등록·수정·삭제를 자기 목록에 반영하므로 "저장 → 재조회" 흐름을
화면 테스트로 그대로 확인할 수 있습니다.
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
- **제출 중 화면 이탈 방지 (7주차)** — 회원가입 화면 최상위를 `PopScope` 로 감싸고
  `canPop` 을 `submitStatus` 에 연결합니다. 성공이든 실패든 제출이 끝나야 다시 뒤로
  갈 수 있습니다. Dialog 는 `PopScope` 만으로는 바깥 탭을 막지 못하므로
  `showDialog(barrierDismissible: false)` 를 함께 씁니다.
- **평점 다중 선택 삭제 (7주차)** — 상단 "편집" 을 누르면 다중 선택 모드가 켜지고,
  카드의 수정·삭제 버튼 자리에 CheckBox 가 들어옵니다. 하나 이상 골라야 하단
  "선택한 N개 삭제" 가 활성화됩니다. 확인 Dialog 는 **요청 전에 닫히고**, 그 뒤부터는
  화면 위 `LoadingOverlay`(어두운 ModalBarrier + 흰 인디케이터)가 진행을 보여주며
  이탈을 막습니다. 단일 삭제는 반대로 요청이 끝날 때까지 Dialog 를 유지합니다.
  일부만 실패하면 **성공한 것만 목록에서 사라지고 실패한 id 는 선택 상태로 남아**
  바로 다시 시도할 수 있으며, 몇 건이 실패했는지 Snackbar 로 알립니다.

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

### No.6 — 등록 성공 응답의 `result` 계약이 Swagger 와 실제 서버에서 다르다

**이슈** 평점 등록(POST) 응답에서 `result` 를 ratingId 로 쓸지 판단할 수 없었다.

**문제** Swagger 설명에는 `result` 가 ratingId 숫자라고 적혀 있는데, 같은 응답
schema 의 **예시는 `null`** 이었다. `result!` 로 캐스팅해 두면 서버가 예시대로
null 을 보내는 순간 성공 응답에서 앱이 죽는다.

**해결** 등록 성공은 **status 로만** 판단하고(201) 응답 본문을 파싱하지 않는다.
방금 저장한 평점의 ratingId 가 필요하면 목록을 다시 조회해서 얻는다.
(실호출에서는 `result: 38` 로 숫자가 왔지만, 그래도 계약에 의존하지 않는다)

### No.7 — 수정했더니 후기가 사라졌다

**이슈** 별점만 바꾸려고 PATCH 를 보냈는데 기존 코멘트가 없어졌다.

**문제** `UpdateRatingDto` 는 `comment` 를 생략하면 기존 값을 유지하지 않고
**null 로 덮는다.** PATCH 라는 Method 이름만 보고 "보낸 필드만 바뀐다" 고 가정했다.

**해결** `UpdateRatingRequest.toJson()` 이 `comment` key 를 **항상** 포함하게 했다.
유지할 때는 기존 값을, 지울 때는 명시적으로 null 을 보낸다.
(`test/movie_log_dto_test.dart` 의 "comment 를 생략해도 key 는 남는다" 가 이 회귀를 잡는다)

### No.8 — 저장은 됐는데 화면이 "실패" 로 보여서 409 가 났다

**이슈** 평점을 등록한 뒤 목록 조회가 실패하자 화면이 저장 실패처럼 보였고,
다시 저장을 누르면 "이미 이 영화에 평점을 남기셨습니다"(409)가 떴다.

**문제** 쓰기와 그 뒤의 재조회를 한 `try` 로 묶어 **GET 실패를 저장 실패로** 다뤘다.

**해결** 두 단계를 상태로 분리했다. 쓰기 실패만 `rethrow` 해서 Dialog 가 실패로
처리하고, `_refreshAfterWrite()` 의 GET 실패는 `refreshWarning` 으로만 알린다.
안내 문구도 "저장은 완료됐지만 목록을 불러오지 못했습니다. 조회만 다시 시도해
주세요." 로 두어 같은 쓰기를 다시 보내지 않게 했다.

### No.9 — Dialog 에서 별점을 고르면 입력하던 코멘트가 사라진다

**이슈** 코멘트를 쓰다가 별점을 바꾸면 TextField 가 비워지고 커서가 맨 앞으로 갔다.

**문제** `TextEditingController(text: ...)` 를 `build()` 안에서 만들고 있었다.
별점 선택이 `setState` 를 부를 때마다 Controller 가 새로 만들어졌다.

**해결** `late final _commentController = TextEditingController(...)` 로 State 가
살아 있는 동안 한 번만 만들고, `dispose()` 에서 정리한다.
(`test/interaction_test.dart` 의 "별점을 고르는 동안 입력한 코멘트가 사라지지
않는다" 가 이 회귀를 잡는다)

### No.10 — 평점 화면 테스트가 "학습용 회원가입이 필요합니다" 만 보여준다

**이슈** 6주차 평점 화면 테스트 7건이 목록 대신 안내 문구를 만나 깨졌다.

**문제** 조회 대상이 상수 `sampleMemberId = 1` 에서 `LearningMemberSession.memberId`
로 바뀌었는데, 테스트는 세션 없이 Route 를 띄우고 있었다. 앱에서는 회원가입이 그
값을 채워 주지만 테스트에는 그 단계가 없다.

**해결** `withServices()` 에 `memberId` 를 받아 "이미 가입을 마친 상태" 로 시작할 수
있게 했다. 기본값 `testMemberId = 7` 은 6주차 상수 1 과 다른 값이라, 화면이 세션이
아니라 옛 상수를 계속 쓰고 있으면 테스트가 바로 깨진다.


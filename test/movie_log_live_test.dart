@Tags(['live'])
library;

// 실제 MovieLog 백엔드(워크북 v6 가입 + v7 인증/평점)를 호출해 연동을 확인한다.
//
// 기본 `flutter test` 에서는 dart_test.yaml 의 tag 설정으로 건너뛴다.
// 확인할 때만 다음으로 실행한다:
//
//   flutter test --tags live --run-skipped
//
// 평점과 TMDB 영화 정보를 함께 묶는 테스트는 .env 의 TMDB_ACCESS_TOKEN 도 쓴다.
//
// 이 테스트는 **학습용 계정을 실제로 만든다.** 매번 새 이메일·닉네임을 쓰고,
// 만든 평점은 같은 테스트 안에서 지운다. 비밀번호와 Token 은 출력하지 않는다.
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/core/network/api_error.dart';
import 'package:movielog/core/network/movie_log_client.dart';
import 'package:movielog/core/network/tmdb_client.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/login_models.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/services/auth_api_service.dart';
import 'package:movielog/data/services/member_api_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/view_models/session_rating_store.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';

import 'fakes/fake_auth.dart';

/// 테스트가 만들 계정. 같은 값을 다시 쓰면 409 가 되므로 실행마다 다르게 둔다.
String _unique() => DateTime.now().millisecondsSinceEpoch.toString();

void main() {
  late Dio publicClient;
  late Dio authClient;

  /// 기기 저장소 대신 쓰는 메모리 TokenStorage. 실제 Interceptor 가 여기서 읽는다.
  late FakeTokenStorage tokenStorage;

  late SignUpService signUpService;
  late AuthApiService authApiService;
  late MemberApiService memberApiService;
  late RatingApiService ratingService;
  late TmdbMovieService movieService;

  /// 이 파일이 만든 학습용 회원. 첫 가입 테스트에서 채워진다.
  int? createdMemberId;
  late String createdEmail;
  late String createdNickname;

  // 비밀번호 규칙: 8자 이상 + 소문자·대문자·숫자·특수문자.
  const password = 'MovieLog7!';

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: '.env');

    // 8주차: Client 를 공개용과 보호용으로 나눈다.
    // 보호용에만 AuthInterceptor 가 붙어 Authorization Header 를 싣는다.
    tokenStorage = FakeTokenStorage();
    publicClient = createMovieLogClient();
    authClient = createAuthMovieLogClient(tokenStorage);

    signUpService = SignUpService(publicClient);
    authApiService = AuthApiService(publicClient);
    memberApiService = MemberApiService(authClient);
    ratingService = RatingApiService(publicClient, authClient);
    movieService = TmdbMovieService(createTmdbClient());

    final suffix = _unique();
    createdEmail = 'movielog$suffix@example.com';
    // 닉네임은 2~12자 제한이 있으므로 뒤 6자리만 쓴다.
    createdNickname = 'mlog${suffix.substring(suffix.length - 6)}';
  });

  setUp(() {
    // flutter_test 의 binding 은 모든 HTTP 요청에 400 을 돌려주는 Mock Client 를
    // HttpOverrides.global 에 끼워 둔다. 실제 서버를 부르려면 그것을 걷어내야 한다.
    HttpOverrides.global = null;
  });

  group('회원가입', () {
    test('POST /v6/members — 201 공통 응답의 result 에서 memberId 를 읽는다', () async {
      final response = await signUpService.signUp(
        CreateMemberRequest(
          email: createdEmail,
          password: password,
          nickname: createdNickname,
        ),
      );

      expect(response.isSuccess, isTrue);
      expect(response.result, isNotNull);
      expect(response.result!.memberId, greaterThan(0));
      expect(response.result!.email, equals(createdEmail));
      expect(response.result!.nickname, equals(createdNickname));

      createdMemberId = response.result!.memberId;
    });

    test('같은 값으로 다시 가입하면 409 가 최종 중복 결과다', () async {
      try {
        await signUpService.signUp(
          CreateMemberRequest(
            email: createdEmail,
            password: password,
            nickname: createdNickname,
          ),
        );
        fail('409 가 와야 합니다');
      } on DioException catch (error) {
        expect(error.response?.statusCode, equals(409));
        expect(error.response?.data, containsPair('code', 'COMMON409'));
        // 서버 문구를 그대로 화면에 보여준다.
        expect(writeSignUpErrorMessage(error), isNotEmpty);
      }
    });

    test('비밀번호 형식 위반은 400 으로 돌아온다', () async {
      try {
        await signUpService.signUp(
          CreateMemberRequest(
            email: 'weak${_unique()}@example.com',
            // 소문자만. 대문자·숫자·특수문자가 없다.
            password: 'onlylower',
            nickname: 'weak${_unique().substring(7)}',
          ),
        );
        fail('400 이 와야 합니다');
      } on DioException catch (error) {
        expect(error.response?.statusCode, equals(400));
        // 이 문구에 "비밀번호" 가 들어 있으면 화면은 입력칸 errorText 로 보여준다.
        expect(writeSignUpErrorMessage(error), contains('비밀번호'));
      }
    });

    test('가입한 닉네임·이메일은 중복 확인에서 false 가 된다', () async {
      expect(await signUpService.checkNickname(createdNickname), isFalse);
      expect(await signUpService.checkEmail(createdEmail), isFalse);

      // 아무도 쓰지 않은 값은 true 다.
      expect(await signUpService.checkNickname('free${_unique().substring(7)}'),
          isTrue);
    });

    test('중복 확인 결과가 ViewModel 의 상태로 이어진다', () async {
      final viewModel = SignUpViewModel(signUpService);

      viewModel.onNicknameChanged(createdNickname);
      await viewModel.checkNickname(createdNickname);

      // 방금 내가 만든 닉네임이므로 중복이어야 한다.
      expect(viewModel.nicknameCheckStatus, equals(CheckStatus.duplicated));
    });
  });

  group('로그인과 내 정보 (v7)', () {
    test('POST /v7/auth/login — result 에 nickname 과 accessToken 이 온다', () async {
      final result = await authApiService.login(
        LoginRequest(email: createdEmail, password: password),
      );

      expect(result.nickname, equals(createdNickname));
      expect(result.accessToken, isNotEmpty);
      // 응답에 memberId 는 없다. 명세에 없는 값을 꺼내 쓰지 않는다.
      expect(result.toString(), isNot(contains(result.accessToken)));

      // 이후 보호 요청이 쓸 수 있도록 저장한다.
      await tokenStorage.saveAccessToken(result.accessToken);
    });

    test('틀린 비밀번호는 AUTH401_1 이다 (세션 만료가 아니다)', () async {
      try {
        await authApiService.login(
          LoginRequest(email: createdEmail, password: 'WrongPw1!'),
        );
        fail('401 이 와야 합니다');
      } on DioException catch (error) {
        expect(error.response?.statusCode, equals(401));
        expect(apiErrorCode(error), equals('AUTH401_1'));
        // 로그인 실패는 전역 세션 정리 대상이 아니다.
        expect(isSessionExpiredCode(apiErrorCode(error)), isFalse);
      }
    });

    test('Token 없이 GET /v7/members/me 를 부르면 AUTH401_2 다', () async {
      // 공개용 Client 에는 Interceptor 가 없으므로 Header 가 붙지 않는다.
      try {
        await publicClient.get('/v7/members/me');
        fail('401 이 와야 합니다');
      } on DioException catch (error) {
        expect(error.response?.statusCode, equals(401));
        expect(apiErrorCode(error), equals('AUTH401_2'));
        expect(isSessionExpiredCode(apiErrorCode(error)), isTrue);
      }
    });

    test('GET /v7/members/me — 이메일·닉네임·가입일을 돌려준다', () async {
      final me = await memberApiService.fetchMe();

      expect(me.email, equals(createdEmail));
      expect(me.nickname, equals(createdNickname));
      expect(me.createdAt, isNotNull);
    });

    test('PATCH /v7/members/me — 같은 닉네임은 409 가 아니다', () async {
      final same = await memberApiService.updateNickname(createdNickname);
      expect(same.nickname, equals(createdNickname));

      final renamed = 'edit${_unique().substring(_unique().length - 6)}';
      final updated = await memberApiService.updateNickname(renamed);
      expect(updated.nickname, equals(renamed));
      createdNickname = renamed;
    });

    test('restoreSession 은 Token 을 서버에 확인한 뒤에만 signedIn 이 된다', () async {
      final viewModel = AuthViewModel(
        authApiService,
        memberApiService,
        tokenStorage,
      );
      await viewModel.restoreSession();

      expect(viewModel.status, equals(AuthStatus.signedIn));
      expect(viewModel.member?.email, equals(createdEmail));
    });
  });

  group('평점 CRUD (v7 보호 API)', () {
    /// 가입 테스트가 먼저 돌아 memberId 가 채워져 있어야 한다.
    int memberId() {
      final id = createdMemberId;
      if (id == null) fail('회원가입 테스트가 먼저 성공해야 합니다');
      return id;
    }

    // TMDB 의 Fight Club. movieId 는 배열 index 가 아니라 TMDB id 다.
    const movieId = 550;
    int? ratingId;

    test('새 회원의 평점 목록은 빈 배열이다', () async {
      final ratings = await ratingService.fetchMyRatings(memberId());

      // 빈 배열은 실패가 아니다.
      expect(ratings, isEmpty);
    });

    test('POST /v7/ratings — 성공 result 가 Rating 객체다', () async {
      final created = await ratingService.createRating(
        const CreateRatingRequest(
          movieId: movieId,
          score: 5,
          comment: '라이브 테스트 등록',
        ),
      );

      // v6 은 result 계약이 불확실해 재조회로 확인했다. v7 은 그 자리에서 확인된다.
      expect(created.movieId, equals(movieId));
      expect(created.score, equals(5));
      expect(created.comment, equals('라이브 테스트 등록'));

      // 공개 조회로도 같은 값이 보인다.
      final ratings = await ratingService.fetchMyRatings(memberId());
      expect(ratings, hasLength(1));
      expect(ratings.first.ratingId, equals(created.ratingId));

      ratingId = created.ratingId;
    });

    test('같은 영화에 다시 등록하면 RATING409_1 이다', () async {
      try {
        await ratingService.createRating(
          const CreateRatingRequest(movieId: movieId, score: 3),
        );
        fail('409 가 와야 합니다');
      } on DioException catch (error) {
        expect(error.response?.statusCode, equals(409));
        expect(apiErrorCode(error), equals('RATING409_1'));
        // 409 는 기존 기록을 확인하면 되는 오류라 재조회가 필요 없다.
        expect(shouldRefreshAfterRatingError(error), isFalse);
      }
    });

    test('PATCH — comment 를 함께 보내면 후기가 유지된다', () async {
      final id = ratingId;
      if (id == null) fail('등록 테스트가 먼저 성공해야 합니다');

      final updated = await ratingService.updateRating(
        ratingId: id,
        score: 4,
        comment: '라이브 테스트 수정',
      );

      // v7 수정도 Rating 객체를 돌려주므로 재조회 없이 확인된다.
      expect(updated.score, equals(4));
      expect(updated.comment, equals('라이브 테스트 수정'));
    });

    test('PATCH 는 부분 수정이 아니라 전체 교체다', () async {
      final id = ratingId;
      if (id == null) fail('등록 테스트가 먼저 성공해야 합니다');

      // comment 를 비우면 기존 후기가 null 로 덮인다. 숨기지 않고 확인한다.
      final cleared = await ratingService.updateRating(ratingId: id, score: 4);
      expect(cleared.comment, isNull);

      await ratingService.updateRating(
        ratingId: id,
        score: 4,
        comment: '라이브 테스트 수정',
      );
    });

    test('없는 평점을 수정하면 RATING404_1 이고 재조회가 필요하다', () async {
      try {
        await ratingService.updateRating(ratingId: 99999999, score: 4);
        fail('404 가 와야 합니다');
      } on DioException catch (error) {
        expect(error.response?.statusCode, equals(404));
        expect(apiErrorCode(error), equals('RATING404_1'));
        expect(writeErrorMessage(error), contains('평점'));
        expect(shouldRefreshAfterRatingError(error), isTrue);
      }
    });

    test('평점의 movieId 로 TMDB 영화 정보까지 함께 묶는다', () async {
      final auth = AuthViewModel(
        authApiService,
        memberApiService,
        tokenStorage,
      );
      final viewModel = MyRatingsViewModel(
        ratingService,
        movieService,
        auth,
        SessionRatingStore(),
        memberId: memberId(),
      );
      await viewModel.load();

      expect(viewModel.status, equals(MyRatingsLoadStatus.success));
      expect(viewModel.ratings, isNotEmpty);

      // 평점은 자체 백엔드, 제목·포스터는 TMDB 에서 온다.
      final entry = viewModel.ratings.first;
      expect(entry.movie, isNotNull);
      expect(entry.movie!.id, equals(entry.rating.movieId));
      expect(entry.movie!.title, isNotEmpty);
    });

    test('DELETE — v7 은 204 가 아니라 200 + result null 이다', () async {
      final id = ratingId;
      if (id == null) fail('등록 테스트가 먼저 성공해야 합니다');

      // v6 의 `statusCode != 204` 검사를 그대로 두면 성공한 삭제가 실패로 보인다.
      await ratingService.deleteRating(id);

      final ratings = await ratingService.fetchMyRatings(memberId());
      expect(ratings, isEmpty);
    });

    test('존재하지 않는 회원 — 조회 404 를 우리 문구로 바꾼다', () async {
      try {
        await ratingService.fetchMyRatings(99999999);
        fail('404 가 와야 합니다');
      } on DioException catch (error) {
        expect(error.response?.statusCode, equals(404));
        expect(writeMyRatingsErrorMessage(error), equals('존재하지 않는 회원입니다.'));
      }
    });

    test('memberId 형식 오류 — 조회 400 을 우리 문구로 바꾼다', () async {
      // fetchMyRatings 는 int 만 받으므로 잘못된 경로는 Client 로 직접 부른다.
      try {
        await publicClient.get('/v7/members/abc/ratings');
        fail('400 이 와야 합니다');
      } on DioException catch (error) {
        expect(error.response?.statusCode, equals(400));
        expect(
          writeMyRatingsErrorMessage(error),
          equals('memberId 형식을 다시 확인해 주세요.'),
        );
      }
    });
  });
}

@Tags(['live'])
library;

// 실제 MovieLog 백엔드(워크북 v6)를 호출해 연동을 확인하는 테스트.
//
// 기본 `flutter test` 에서는 dart_test.yaml 의 tag 설정으로 건너뛴다.
// 확인할 때만 다음으로 실행한다:
//
//   flutter test --tags live --run-skipped
//
// 평점과 TMDB 영화 정보를 함께 묶는 테스트는 .env 의 TMDB_ACCESS_TOKEN 도 쓴다.
//
// 이 테스트는 **학습용 계정을 실제로 만든다.** 매번 새 이메일·닉네임을 쓰고,
// 만든 평점은 같은 테스트 안에서 지운다. 비밀번호는 출력하지 않는다.
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/core/network/movie_log_client.dart';
import 'package:movielog/core/network/tmdb_client.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';

/// 테스트가 만들 계정. 같은 값을 다시 쓰면 409 가 되므로 실행마다 다르게 둔다.
String _unique() => DateTime.now().millisecondsSinceEpoch.toString();

void main() {
  late Dio client;
  late SignUpService signUpService;
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

    client = createMovieLogClient();
    signUpService = SignUpService(client);
    ratingService = RatingApiService(client);
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

  group('평점 CRUD', () {
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

    test('POST — 등록 뒤 GET 으로 저장을 확인한다', () async {
      await ratingService.createRating(
        memberId: memberId(),
        request: const CreateRatingRequest(
          movieId: movieId,
          score: 5,
          comment: '라이브 테스트 등록',
        ),
      );

      final ratings = await ratingService.fetchMyRatings(memberId());
      expect(ratings, hasLength(1));
      expect(ratings.first.movieId, equals(movieId));
      expect(ratings.first.score, equals(5));
      expect(ratings.first.comment, equals('라이브 테스트 등록'));

      ratingId = ratings.first.ratingId;
    });

    test('같은 영화에 다시 등록하면 409 다', () async {
      try {
        await ratingService.createRating(
          memberId: memberId(),
          request: const CreateRatingRequest(movieId: movieId, score: 3),
        );
        fail('409 가 와야 합니다');
      } on DioException catch (error) {
        expect(error.response?.statusCode, equals(409));
        // 409 는 값만 고치거나 다시 시도하면 되는 오류라 재조회가 필요 없다.
        expect(shouldRefreshAfterRatingError(error), isFalse);
      }
    });

    test('PATCH — comment 를 함께 보내면 후기가 유지된다', () async {
      final id = ratingId;
      if (id == null) fail('등록 테스트가 먼저 성공해야 합니다');

      await ratingService.updateRating(
        memberId: memberId(),
        ratingId: id,
        request: const UpdateRatingRequest(score: 4, comment: '라이브 테스트 수정'),
      );

      final ratings = await ratingService.fetchMyRatings(memberId());
      expect(ratings.first.score, equals(4));
      expect(ratings.first.comment, equals('라이브 테스트 수정'));
    });

    test('없는 평점을 수정하면 404 이고 재조회가 필요하다', () async {
      try {
        await ratingService.updateRating(
          memberId: memberId(),
          ratingId: 99999999,
          request: const UpdateRatingRequest(score: 4),
        );
        fail('404 가 와야 합니다');
      } on DioException catch (error) {
        expect(error.response?.statusCode, equals(404));
        expect(writeErrorMessage(error), contains('평점'));
        expect(shouldRefreshAfterRatingError(error), isTrue);
      }
    });

    test('평점의 movieId 로 TMDB 영화 정보까지 함께 묶는다', () async {
      final viewModel = MyRatingsViewModel(
        ratingService,
        movieService,
        memberId(),
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

    test('DELETE — 204 를 파싱하지 않고 성공으로 처리한다', () async {
      final id = ratingId;
      if (id == null) fail('등록 테스트가 먼저 성공해야 합니다');

      await ratingService.deleteRating(memberId: memberId(), ratingId: id);

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
        await client.get('/v6/members/abc/ratings');
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

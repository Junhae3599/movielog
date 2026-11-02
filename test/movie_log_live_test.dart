@Tags(['live'])
library;

// 실제 MovieLog 백엔드(워크북 v5)를 호출해 연동을 확인하는 테스트.
//
// 기본 `flutter test` 에서는 dart_test.yaml 의 tag 설정으로 건너뛴다.
// 확인할 때만 다음으로 실행한다:
//
//   flutter test --tags live --run-skipped
//
// 평점과 TMDB 영화 정보를 함께 묶는 테스트는 .env 의 TMDB_ACCESS_TOKEN 도 쓴다.
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/core/network/movie_log_client.dart';
import 'package:movielog/core/network/tmdb_client.dart';
import 'package:movielog/data/services/member_check_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';

void main() {
  late Dio client;
  late MemberCheckService checkService;
  late RatingApiService ratingService;
  late TmdbMovieService movieService;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: '.env');

    client = createMovieLogClient();
    checkService = MemberCheckService(client);
    ratingService = RatingApiService(client);
    movieService = TmdbMovieService(createTmdbClient());
  });

  setUp(() {
    // flutter_test 의 binding 은 모든 HTTP 요청에 400 을 돌려주는 Mock Client 를
    // HttpOverrides.global 에 끼워 둔다. 실제 서버를 부르려면 그것을 걷어내야 한다.
    HttpOverrides.global = null;
  });

  test('닉네임 중복 확인 — 200 응답의 available 을 읽는다', () async {
    final available = await checkService.checkNickname('무비러버');

    // 그 값이 true 인지 false 인지는 서버 데이터에 달렸다.
    // 여기서는 요청이 200 으로 돌아와 bool 로 파싱되는 것까지 확인한다.
    expect(available, isA<bool>());
  });

  test('이메일 중복 확인 — 200 응답의 available 을 읽는다', () async {
    final available = await checkService.checkEmail('movie@example.com');

    expect(available, isA<bool>());
  });

  test('중복 확인 결과가 ViewModel 의 상태로 이어진다', () async {
    final viewModel = SignUpViewModel(checkService);

    viewModel.onNicknameChanged('무비러버');
    await viewModel.checkNickname('무비러버');

    // 통신이 성공했으면 available 또는 duplicated 중 하나다. error 면 안 된다.
    expect(
      viewModel.nicknameCheckStatus,
      anyOf(CheckStatus.available, CheckStatus.duplicated),
    );
  });

  test('유저별 평점 조회 — memberId 1 의 평점을 DTO 로 바꾼다', () async {
    final ratings = await ratingService.fetchMyRatings(sampleMemberId);

    expect(ratings, isNotEmpty);
    for (final rating in ratings) {
      expect(rating.ratingId, greaterThan(0));
      expect(rating.movieId, greaterThan(0));
      expect(rating.score, inInclusiveRange(1, 5));
      // comment 는 null 일 수 있다. createdAt 은 항상 파싱되어야 한다.
      expect(rating.createdAt.year, greaterThan(2000));
    }
  });

  test('존재하지 않는 회원 — 404 를 우리 문구로 바꾼다', () async {
    try {
      await ratingService.fetchMyRatings(99999);
      fail('404 가 와야 합니다');
    } on DioException catch (error) {
      expect(error.response?.statusCode, equals(404));
      // v5 는 실패만 {message, error, statusCode} 로 내려준다.
      expect(error.response?.data, containsPair('statusCode', 404));
      expect(writeMyRatingsErrorMessage(error), equals('존재하지 않는 회원입니다.'));
    }
  });

  test('memberId 형식 오류 — 400 을 우리 문구로 바꾼다', () async {
    // fetchMyRatings 는 int 만 받으므로 잘못된 경로는 Client 로 직접 부른다.
    try {
      await client.get('/v5/members/abc/ratings');
      fail('400 이 와야 합니다');
    } on DioException catch (error) {
      expect(error.response?.statusCode, equals(400));
      expect(
        writeMyRatingsErrorMessage(error),
        equals('memberId 형식을 다시 확인해 주세요.'),
      );
    }
  });

  test('평점의 movieId 로 TMDB 영화 정보까지 함께 묶는다', () async {
    final viewModel = MyRatingsViewModel(
      ratingService,
      movieService,
      sampleMemberId,
    );
    await viewModel.load();

    expect(viewModel.status, equals(MyRatingsLoadStatus.success));
    expect(viewModel.ratings, isNotEmpty);

    // 평점은 자체 백엔드, 제목·포스터는 TMDB 에서 온다.
    final matched = viewModel.ratings.where((entry) => entry.movie != null);
    expect(matched, isNotEmpty);
    for (final entry in matched) {
      expect(entry.movie!.id, equals(entry.rating.movieId));
      expect(entry.movie!.title, isNotEmpty);
    }
  });
}

// TmdbMovieService 를 대신하는 Fake.
//
// UI Layer 는 Data Layer 가 돌려주는 DTO 타입만 알면 되므로,
// 그 값이 실제 TMDB 응답인지 이 Fake 의 응답인지 몰라도 된다.
import 'package:dio/dio.dart';
import 'package:movielog/data/models/tmdb_genre_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page_dto.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';

import 'tmdb_fixtures.dart';

/// Fake 가 어떤 결과를 돌려줄지 고르는 값.
enum FakeTmdbMode {
  /// 정상 응답
  success,

  /// results 가 빈 응답
  empty,

  /// 요청 실패 (DioException)
  failure,

  /// 인증 실패 (401)
  unauthorized,
}

/// Discover 요청 한 번의 기록. 어떤 page·장르로 요청했는지 검증할 때 쓴다.
class DiscoverCall {
  const DiscoverCall({required this.page, required this.genreIds});

  final int page;
  final List<int>? genreIds;

  @override
  String toString() => 'DiscoverCall(page: $page, genreIds: $genreIds)';
}

class FakeTmdbMovieService extends TmdbMovieService {
  FakeTmdbMovieService({
    this.mode = FakeTmdbMode.success,
    this.delay = Duration.zero,
    this.pageSize = 20,
    this.totalPages = 3,
    this.duplicateAcrossPages = false,
    this.genreResultCount,
  }) : super(Dio());

  FakeTmdbMode mode;

  /// Loading 상태를 눈으로 확인하기 위한 지연.
  final Duration delay;

  final int pageSize;
  final int totalPages;

  /// 페이지 사이에 같은 영화 id 가 섞여 나오게 한다. (중복 제거 검증용)
  final bool duplicateAcrossPages;

  /// 장르를 지정했을 때 돌려줄 결과 개수. null 이면 전체와 같다.
  final int? genreResultCount;

  final List<DiscoverCall> discoverCalls = [];
  int popularCallCount = 0;
  int genresCallCount = 0;

  @override
  Future<TmdbMoviePageDto> fetchPopular({int page = 1}) async {
    popularCallCount++;
    await _wait();
    _throwIfNeeded('/movie/popular');

    if (mode == FakeTmdbMode.empty) {
      return fakePage(page: page, results: const [], totalPages: 0);
    }

    return fakePage(
      page: page,
      results: List.generate(pageSize, (index) => fakeMovie(index + 1)),
      totalPages: totalPages,
    );
  }

  @override
  Future<TmdbMoviePageDto> discoverMovies({
    required int page,
    List<int>? genreIds,
  }) async {
    discoverCalls.add(DiscoverCall(page: page, genreIds: genreIds));
    await _wait();
    _throwIfNeeded('/discover/movie');

    if (mode == FakeTmdbMode.empty) {
      return fakePage(page: page, results: const [], totalPages: 0);
    }

    final hasGenre = genreIds != null && genreIds.isNotEmpty;
    final limit = hasGenre ? (genreResultCount ?? pageSize) : pageSize;
    if (limit == 0) {
      return fakePage(page: page, results: const [], totalPages: 1);
    }

    // duplicateAcrossPages 가 켜져 있으면 페이지마다 id 가 10개씩만 전진해
    // 이전 페이지와 절반이 겹친다.
    final stride = duplicateAcrossPages ? pageSize ~/ 2 : pageSize;
    final start = (page - 1) * stride;

    return fakePage(
      page: page,
      results: List.generate(
        limit,
        (index) => fakeMovie(
          start + index + 1,
          genreIds: hasGenre ? genreIds : const [28],
        ),
      ),
      totalPages: hasGenre && genreResultCount != null ? 1 : totalPages,
    );
  }

  @override
  Future<List<TmdbGenreDto>> fetchGenres() async {
    genresCallCount++;
    await _wait();
    _throwIfNeeded('/genre/movie/list');
    return fakeGenres;
  }

  Future<void> _wait() async {
    if (delay > Duration.zero) await Future.delayed(delay);
  }

  void _throwIfNeeded(String path) {
    final options = RequestOptions(path: path);

    switch (mode) {
      case FakeTmdbMode.failure:
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'fake network failure',
        );
      case FakeTmdbMode.unauthorized:
        throw DioException(
          requestOptions: options,
          response: Response<dynamic>(
            requestOptions: options,
            statusCode: 401,
          ),
          type: DioExceptionType.badResponse,
          message: 'fake 401',
        );
      case FakeTmdbMode.success:
      case FakeTmdbMode.empty:
        return;
    }
  }
}

/// 테스트 안에서만 쓰는 도우미: 이 Fake 가 받은 Discover 요청의 page 목록.
extension DiscoverCallPages on List<DiscoverCall> {
  List<int> get pages => map((call) => call.page).toList();
  List<List<int>?> get genreIds => map((call) => call.genreIds).toList();
}

/// 모든 영화 id 를 모아 중복 여부를 확인할 때 쓴다.
extension MovieIds on List<TmdbMovieDto> {
  List<int> get ids => map((movie) => movie.id).toList();
}

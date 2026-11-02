// lib/data/services/tmdb_movie_service.dart
import 'package:dio/dio.dart';

import '../models/tmdb_genre_dto.dart';
import '../models/tmdb_movie_page_dto.dart';

/// TMDB 서버와 직접 통신하는 Service Layer.
///
/// 담당하는 일: HTTP 요청을 보내고 응답 JSON 을 DTO 로 바꾼다.
/// 담당하지 않는 일: "인기 5개", "최대 30개", "선택된 장르" 처럼 화면마다 달라지는
/// 정책은 ViewModel 의 책임이다.
///
/// 이 클래스는 상태를 갖지 않으므로(stateless) 호출할 때마다 새 응답을 돌려준다.
/// 그래서 화면이 다른 여러 ViewModel 이 같은 인스턴스 하나를 안전하게 공유할 수 있다.
class TmdbMovieService {
  TmdbMovieService(this._dio);

  final Dio _dio;

  /// 인기순 영화 목록. GET /movie/popular
  Future<TmdbMoviePageDto> fetchPopular({int page = 1}) async {
    final response = await _dio.get(
      '/movie/popular',
      queryParameters: {'language': 'ko-KR', 'page': page},
    );
    return TmdbMoviePageDto.fromJson(response.data as Map<String, dynamic>);
  }

  /// 조건으로 탐색하는 영화 목록. GET /discover/movie
  ///
  /// [genreIds] 가 비어 있거나 null 이면 `with_genres` 를 아예 보내지 않는다.
  /// (= "전체") 여러 개를 넘기면 OR(`|`) 로 연결해 보낸다.
  Future<TmdbMoviePageDto> discoverMovies({
    required int page,
    List<int>? genreIds,
  }) async {
    final hasGenre = genreIds != null && genreIds.isNotEmpty;

    final response = await _dio.get(
      '/discover/movie',
      queryParameters: {
        'language': 'ko-KR',
        'page': page,
        'sort_by': 'popularity.desc',
        'include_adult': false,
        'include_video': false,
        if (hasGenre) 'with_genres': genreIds.join('|'),
      },
    );
    return TmdbMoviePageDto.fromJson(response.data as Map<String, dynamic>);
  }

  /// 영화의 공식 장르 목록. GET /genre/movie/list
  Future<List<TmdbGenreDto>> fetchGenres() async {
    final response = await _dio.get(
      '/genre/movie/list',
      queryParameters: {'language': 'ko'},
    );

    final data = response.data as Map<String, dynamic>;
    final genres = data['genres'] as List<dynamic>? ?? const [];
    return genres
        .map((item) => TmdbGenreDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

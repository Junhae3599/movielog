// TMDB 응답을 흉내내는 테스트 fixture.
//
// 실제 TMDB 서버에 요청을 보내지 않고도 ViewModel·화면을 검증할 수 있게 한다.
// (Token 이 없거나 TMDB 가 점검 중이어도 테스트는 돌아간다)
import 'package:movielog/data/models/tmdb_genre_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page_dto.dart';

/// Genre API 가 돌려주는 장르 목록. id 는 TMDB 의 실제 장르 ID 다.
const fakeGenres = [
  TmdbGenreDto(id: 28, name: '액션'),
  TmdbGenreDto(id: 878, name: 'SF'),
  TmdbGenreDto(id: 16, name: '애니메이션'),
  TmdbGenreDto(id: 18, name: '드라마'),
];

/// 영화 한 편을 만든다. 지정하지 않은 값은 그럴듯한 기본값으로 채운다.
TmdbMovieDto fakeMovie(
  int id, {
  String? title,
  String? posterPath = '/poster.jpg',
  String? releaseDate = '2024-05-17',
  List<int> genreIds = const [28],
  double voteAverage = 7.5,
}) {
  return TmdbMovieDto(
    id: id,
    title: title ?? '영화 $id',
    overview: '영화 $id 의 줄거리',
    posterPath: posterPath,
    backdropPath: '/backdrop.jpg',
    releaseDate: releaseDate,
    genreIds: genreIds,
    voteAverage: voteAverage,
    popularity: (100 - id).toDouble(),
  );
}

/// 페이지 응답 하나를 만든다.
TmdbMoviePageDto fakePage({
  required int page,
  required List<TmdbMovieDto> results,
  required int totalPages,
}) {
  return TmdbMoviePageDto(
    page: page,
    results: results,
    totalPages: totalPages,
    totalResults: totalPages * 20,
  );
}

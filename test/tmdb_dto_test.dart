// TMDB JSON → DTO 변환 테스트
//
// snake_case 와 lowerCamelCase 연결, null 처리, num → double 변환을 확인한다.

import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/data/models/tmdb_genre_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page_dto.dart';

void main() {
  group('TmdbMovieDto', () {
    test('snake_case key 를 camelCase 필드로 연결한다', () {
      final dto = TmdbMovieDto.fromJson(const {
        'id': 550,
        'title': '파이트 클럽',
        'overview': '줄거리',
        'poster_path': '/poster.jpg',
        'backdrop_path': '/backdrop.jpg',
        'release_date': '1999-10-15',
        'genre_ids': [18, 53],
        'vote_average': 8.4,
        'popularity': 120.5,
      });

      expect(dto.id, equals(550));
      expect(dto.posterPath, equals('/poster.jpg'));
      expect(dto.backdropPath, equals('/backdrop.jpg'));
      expect(dto.releaseDate, equals('1999-10-15'));
      expect(dto.genreIds, equals([18, 53]));
      expect(dto.voteAverage, equals(8.4));
    });

    test('null 과 누락된 값을 안전하게 채운다', () {
      final dto = TmdbMovieDto.fromJson(const {
        'id': 1,
        'title': null,
        'poster_path': null,
        'genre_ids': null,
      });

      expect(dto.title, equals('제목 없음'));
      expect(dto.overview, isEmpty);
      // 포스터가 없으면 null 로 남겨 화면에서 placeholder 를 그린다.
      expect(dto.posterPath, isNull);
      expect(dto.releaseDate, isNull);
      expect(dto.genreIds, isEmpty);
      expect(dto.voteAverage, equals(0));
    });

    test('정수로 온 vote_average 도 double 로 변환한다', () {
      final dto = TmdbMovieDto.fromJson(const {
        'id': 1,
        'vote_average': 8,
        'popularity': 3,
      });

      expect(dto.voteAverage, equals(8.0));
      expect(dto.popularity, equals(3.0));
    });

    test('release_date 가 없거나 비어 있으면 연도를 표시하지 않는다', () {
      expect(TmdbMovieDto.fromJson(const {'id': 1}).releaseYear, isNull);
      expect(
        TmdbMovieDto.fromJson(const {'id': 1, 'release_date': ''}).releaseYear,
        isNull,
      );
      expect(
        TmdbMovieDto.fromJson(
          const {'id': 1, 'release_date': '2024-05-17'},
        ).releaseYear,
        equals(2024),
      );
    });
  });

  group('TmdbMoviePageDto', () {
    test('results 를 영화 DTO 목록으로 바꾸고 metadata 를 함께 담는다', () {
      final page = TmdbMoviePageDto.fromJson(const {
        'page': 2,
        'results': [
          {'id': 1, 'title': '첫 번째'},
          {'id': 2, 'title': '두 번째'},
        ],
        'total_pages': 100,
        'total_results': 2000,
      });

      expect(page.page, equals(2));
      expect(page.results, hasLength(2));
      expect(page.results.first.title, equals('첫 번째'));
      // total_pages 가 있어야 다음 페이지 요청 여부를 판단할 수 있다.
      expect(page.totalPages, equals(100));
      expect(page.totalResults, equals(2000));
    });

    test('results 가 없어도 빈 목록으로 다룬다', () {
      final page = TmdbMoviePageDto.fromJson(const {'page': 1});

      expect(page.results, isEmpty);
      expect(page.totalPages, equals(0));
    });
  });

  group('TmdbGenreDto', () {
    test('id 와 name 을 그대로 담는다', () {
      final genre = TmdbGenreDto.fromJson(const {'id': 28, 'name': '액션'});

      expect(genre.id, equals(28));
      expect(genre.name, equals('액션'));
    });

    test('genre_ids 를 장르 이름으로 바꾼다', () {
      const genres = [
        TmdbGenreDto(id: 28, name: '액션'),
        TmdbGenreDto(id: 878, name: 'SF'),
      ];

      expect(genres.namesOf(const [878, 28]), equals(['SF', '액션']));
      // 목록에 없는 id 는 조용히 건너뛴다.
      expect(genres.namesOf(const [99999]), isEmpty);
      expect(genres.namesOf(const []), isEmpty);
    });
  });
}

// lib/data/mock_movies.dart
import 'movie.dart';

/// 장르 필터에 사용할 목록. 첫 항목은 필터를 걸지 않는 상태를 뜻한다.
const allGenresLabel = '전체';

const genres = [
  allGenresLabel,
  '드라마',
  'SF',
  '애니메이션',
  '스릴러',
  '로맨스',
];

const movies = [
  Movie(
    id: 1,
    title: '별빛 아래 우리',
    genres: ['로맨스', '드라마'],
    year: 2024,
    runtimeMinutes: 124,
    posterAsset: 'assets/images/posters/hero_under_the_starlight.jpg',
    rating: 4.5,
    ratingCount: 1245,
    synopsis: '바쁜 현대 사회 속에서 서로의 존재를 잊고 살아가던 두 남녀가 우연한 계기로 작은 '
        '천문대에서 만나게 됩니다. 매일 밤 별을 관측하며 서로의 상처를 치유하고, 잊고 있던 꿈과 '
        '사랑을 다시금 깨닫게 되는 따뜻한 이야기입니다.\n\n'
        '별이 쏟아지는 밤하늘 아래, 그들이 나눈 조용한 약속들은 과연 영원할 수 있을까요?',
  ),
  Movie(
    id: 2,
    title: '우주의 끝에서',
    genres: ['SF'],
    year: 2024,
    runtimeMinutes: 138,
    posterAsset: 'assets/images/posters/poster_echoes_of_the_void.jpg',
    rating: 4.2,
    ratingCount: 892,
    synopsis: '관측 가능한 우주의 경계에서 정체불명의 신호가 잡힙니다. 탐사선에 홀로 남은 '
        '통신사가 그 신호를 해독하기 시작하면서, 인류가 믿어온 시간의 개념이 흔들립니다.',
  ),
  Movie(
    id: 3,
    title: '속삭이는 숲',
    genres: ['애니메이션'],
    year: 2023,
    runtimeMinutes: 96,
    posterAsset: 'assets/images/posters/poster_whispering_woods.jpg',
    rating: 4.9,
    ratingCount: 2103,
    synopsis: '말을 잃은 소녀가 숲으로 이사 오면서 나무와 바람의 목소리를 듣게 됩니다. '
        '숲이 들려주는 오래된 이야기를 따라가며 소녀는 잃어버린 목소리를 되찾아 갑니다.',
  ),
  Movie(
    id: 4,
    title: '밤의 그림자',
    genres: ['스릴러'],
    year: 2024,
    runtimeMinutes: 112,
    posterAsset: 'assets/images/posters/poster_night_shadows.jpg',
    rating: 3.8,
    ratingCount: 654,
    synopsis: '비 내리는 도시의 뒷골목에서 연쇄 실종 사건이 벌어집니다. 사건을 쫓던 형사는 '
        '자신의 기억 속에서 범인의 얼굴을 발견하고 혼란에 빠집니다.',
  ),
  Movie(
    id: 5,
    title: '심연을 걷는 자',
    genres: ['스릴러', 'SF'],
    year: 2023,
    runtimeMinutes: 129,
    posterAsset: 'assets/images/posters/poster_abyss_walker.jpg',
    rating: 4.1,
    ratingCount: 1078,
    synopsis: '심해 연구소에서 통신이 끊깁니다. 구조대로 내려간 잠수사는 수압보다 무거운 '
        '침묵과 마주하고, 그곳에 남아 있던 것이 무엇인지 알게 됩니다.',
  ),
  Movie(
    id: 6,
    title: '네 번째 오후',
    genres: ['드라마'],
    year: 2022,
    runtimeMinutes: 105,
    posterAsset: 'assets/images/posters/poster_fourth_afternoon.jpg',
    rating: 4.3,
    ratingCount: 431,
    synopsis: '같은 오후를 네 번 반복하게 된 남자가 매번 다른 선택을 하며 자신이 외면해 온 '
        '관계들을 마주합니다.',
  ),
];

/// Path Parameter 로 받은 ID 로 영화를 찾는다. 없으면 null.
Movie? findMovieById(int? id) {
  for (final movie in movies) {
    if (movie.id == id) return movie;
  }
  return null;
}

/// 선택한 장르에 해당하는 영화만 추린다. 비어 있으면 전체를 돌려준다.
List<Movie> filterByGenres(Set<String> selected) {
  if (selected.isEmpty) return movies;
  return movies
      .where((movie) => movie.genres.any(selected.contains))
      .toList();
}

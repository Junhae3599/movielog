// MovieLog 자체 백엔드 응답을 흉내내는 테스트 fixture.
import 'package:dio/dio.dart';
import 'package:movielog/data/models/rating_dto.dart';

/// 평점 한 건을 만든다. 지정하지 않은 값은 그럴듯한 기본값으로 채운다.
RatingDto fakeRating(
  int ratingId, {
  int movieId = 550,
  int score = 5,
  String? comment = '최고의 영화!',
  String createdAt = '2026-09-06T12:14:03.000Z',
}) {
  return RatingDto(
    ratingId: ratingId,
    movieId: movieId,
    score: score,
    comment: comment,
    createdAt: DateTime.parse(createdAt),
  );
}

/// v6 공통 응답 body. (`isSuccess`/`code`/`message`/`result`)
Map<String, dynamic> commonBody({
  bool isSuccess = true,
  String code = 'COMMON200',
  String message = '성공입니다.',
  Object? result,
}) {
  return {
    'isSuccess': isSuccess,
    'code': code,
    'message': message,
    'result': result,
  };
}

/// 회원가입 성공(201) 응답 body.
Map<String, dynamic> signUpSuccessBody({
  required int memberId,
  String email = 'movie@example.com',
  String nickname = '무비러버',
}) {
  return commonBody(
    code: 'COMMON201',
    message: '요청에 성공하였습니다.',
    result: {'memberId': memberId, 'email': email, 'nickname': nickname},
  );
}

/// v6 공통 형식으로 내려오는 실패 응답을 DioException 으로 만든다.
DioException commonError(
  RequestOptions options,
  int statusCode,
  String code,
  String message,
) {
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: statusCode,
      data: commonBody(isSuccess: false, code: code, message: message),
    ),
  );
}

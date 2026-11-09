// MovieLog 자체 백엔드 응답·요청 Model 테스트
//
// 중복 확인과 평점 조회는 공통 Wrapper 없이 결과가 그대로 내려오고(v5 때부터),
// 회원가입·평점 쓰기는 v6 공통 응답으로 감싸진다. 두 계약을 모두 확인한다.

import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/data/models/check_result.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/sign_up_models.dart';

void main() {
  group('CheckResult', () {
    test('available 값을 그대로 읽는다', () {
      expect(CheckResult.fromJson({'available': true}).available, isTrue);
      expect(CheckResult.fromJson({'available': false}).available, isFalse);
    });
  });

  group('RatingDto', () {
    test('응답 JSON 의 모든 key 를 연결한다', () {
      final rating = RatingDto.fromJson({
        'ratingId': 12,
        'movieId': 550,
        'score': 5,
        'comment': '최고의 영화!',
        'createdAt': '2026-09-06T12:14:03.000Z',
        'updatedAt': '2026-09-06T12:14:03.000Z',
      });

      expect(rating.ratingId, equals(12));
      expect(rating.movieId, equals(550));
      expect(rating.score, equals(5));
      expect(rating.comment, equals('최고의 영화!'));
      // "Z" 가 붙은 값은 UTC 로 해석된다. 화면에서 toLocal() 로 바꿔 보여준다.
      expect(rating.createdAt.isUtc, isTrue);
      expect(rating.createdAt.year, equals(2026));
    });

    test('comment 가 null 이어도 파싱된다', () {
      final rating = RatingDto.fromJson({
        'ratingId': 3,
        'movieId': 13,
        'score': 3,
        'comment': null,
        'createdAt': '2026-11-01T19:00:27.956Z',
      });

      expect(rating.comment, isNull);
      expect(rating.score, equals(3));
    });

    test('score 가 5.0 처럼 소수로 와도 정수로 받는다', () {
      final rating = RatingDto.fromJson({
        'ratingId': 1,
        'movieId': 550,
        'score': 5.0,
        'comment': '좋다',
        'createdAt': '2026-09-06T12:14:03.000Z',
      });

      expect(rating.score, equals(5));
    });
  });

  group('CommonResponse', () {
    test('네 필드를 읽고 result 를 제네릭으로 파싱한다', () {
      final response = CommonResponse<SignUpResult>.fromJson({
        'isSuccess': true,
        'code': 'COMMON201',
        'message': '요청에 성공하였습니다.',
        'result': {
          'memberId': 12,
          'email': 'movie@example.com',
          'nickname': '무비러버',
        },
      }, (value) => SignUpResult.fromJson(value as Map<String, dynamic>));

      expect(response.isSuccess, isTrue);
      expect(response.code, equals('COMMON201'));
      expect(response.result!.memberId, equals(12));
      expect(response.result!.nickname, equals('무비러버'));
    });

    test('result 가 null 이면 parseResult 를 부르지 않는다', () {
      var parsed = false;

      final response = CommonResponse<SignUpResult>.fromJson({
        'isSuccess': true,
        'code': 'COMMON200',
        'message': '성공입니다.',
        'result': null,
      }, (value) {
        parsed = true;
        return SignUpResult.fromJson(value as Map<String, dynamic>);
      });

      expect(response.result, isNull);
      expect(parsed, isFalse);
    });

    test('공통 형식이 아닌 오류 body 는 null 로 본다', () {
      // v5 때부터 있던 API 의 실패 응답.
      expect(
        commonErrorOf({
          'message': '존재하지 않는 유저입니다.',
          'error': 'Not Found',
          'statusCode': 404,
        }),
        isNull,
      );
      // body 가 아예 없거나 문자열인 경우.
      expect(commonErrorOf(null), isNull);
      expect(commonErrorOf('Bad Gateway'), isNull);
    });

    test('공통 형식 오류 body 는 code·message 를 돌려준다', () {
      final error = commonErrorOf({
        'isSuccess': false,
        'code': 'COMMON409',
        'message': '이미 사용 중인 이메일입니다.',
        'result': null,
      });

      expect(error!.code, equals('COMMON409'));
      expect(error.message, equals('이미 사용 중인 이메일입니다.'));
    });
  });

  group('CreateMemberRequest', () {
    test('이메일·닉네임은 trim 하고 비밀번호는 건드리지 않는다', () {
      final body = const CreateMemberRequest(
        email: '  movie@example.com ',
        password: ' Password123! ',
        nickname: ' 무비러버 ',
      ).toJson();

      expect(body['email'], equals('movie@example.com'));
      expect(body['nickname'], equals('무비러버'));
      // 공백도 비밀번호의 일부다. 몰래 바꾸면 로그인할 수 없게 된다.
      expect(body['password'], equals(' Password123! '));
    });
  });

  group('validateServerScore', () {
    test('1~5 정수만 통과한다', () {
      expect(validateServerScore(1), equals(1));
      expect(validateServerScore(5), equals(5));
    });

    test('반 점과 범위를 벗어난 값은 거부한다', () {
      // 조용히 toInt() 로 깎지 않고 예외로 알린다.
      expect(() => validateServerScore(3.5), throwsArgumentError);
      expect(() => validateServerScore(0), throwsArgumentError);
      expect(() => validateServerScore(6), throwsArgumentError);
    });
  });

  group('CreateRatingRequest', () {
    test('comment 가 있으면 trim 해서 넣는다', () {
      final body = const CreateRatingRequest(
        movieId: 550,
        score: 5,
        comment: '  최고의 영화!  ',
      ).toJson();

      expect(body['movieId'], equals(550));
      expect(body['score'], equals(5));
      expect(body['comment'], equals('최고의 영화!'));
    });

    test('comment 가 null 이거나 공백이면 key 자체를 보내지 않는다', () {
      expect(
        const CreateRatingRequest(movieId: 550, score: 5).toJson().keys,
        equals(['movieId', 'score']),
      );
      expect(
        const CreateRatingRequest(movieId: 550, score: 5, comment: '   ')
            .toJson()
            .keys,
        equals(['movieId', 'score']),
      );
    });
  });

  group('UpdateRatingRequest', () {
    test('comment 를 유지하려면 값을 명시적으로 함께 보낸다', () {
      final body =
          const UpdateRatingRequest(score: 4, comment: '다시 봐도 좋다').toJson();

      expect(body['score'], equals(4));
      expect(body['comment'], equals('다시 봐도 좋다'));
    });

    test('comment 를 생략해도 key 는 남는다', () {
      // PATCH 는 comment key 가 없으면 기존 후기를 null 로 덮는다. 그 의도를
      // 숨기지 않고 항상 보낸다.
      final body = const UpdateRatingRequest(score: 4).toJson();

      expect(body.containsKey('comment'), isTrue);
      expect(body['comment'], isNull);
    });

    test('빈 문자열은 후기 없음(null)으로 보낸다', () {
      expect(
        const UpdateRatingRequest(score: 4, comment: '  ').toJson()['comment'],
        isNull,
      );
    });
  });
}

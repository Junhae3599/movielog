import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'movie_log_app.dart';

Future<void> main() async {
  // dotenv.load() 가 끝나기 전에 .env 값을 읽으면 빈 값이 돌아온다.
  // 그래서 runApp() 이전에 반드시 await 로 로드를 끝낸다.
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  runApp(const MovieLogApp());
}

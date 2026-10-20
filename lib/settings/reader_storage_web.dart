import 'package:web/web.dart' as web;

const _key = 'arkstory.reader-settings.v1';
Future<String?> read() async => web.window.localStorage.getItem(_key);
Future<void> write(String value) async =>
    web.window.localStorage.setItem(_key, value);

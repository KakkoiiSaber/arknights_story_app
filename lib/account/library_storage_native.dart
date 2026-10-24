import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<File> _file() async {
  final root = await getApplicationSupportDirectory();
  await root.create(recursive: true);
  return File('${root.path}/reading-library.json');
}

Future<String?> read() async {
  final file = await _file();
  return await file.exists() ? file.readAsString() : null;
}

Future<void> write(String value) async {
  final file = await _file();
  final pending = File('${file.path}.tmp');
  await pending.writeAsString(value, flush: true);
  await pending.rename(file.path);
}

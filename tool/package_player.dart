import 'dart:io';
import 'package:archive/archive.dart';

void main() {
  final root = Directory('web/prts-player');
  if (!File('${root.path}/manifest.html').existsSync()) {
    throw StateError('Run npm run build:player first');
  }
  final archive = Archive();
  for (final file in root.listSync(recursive: true).whereType<File>()) {
    if (file.path.endsWith('.map')) continue;
    final path = file.path
        .substring(root.path.length + 1)
        .replaceAll('\\', '/');
    archive.addFile(ArchiveFile.bytes(path, file.readAsBytesSync()));
  }
  final output = File('lib/assets/prts_player.zip');
  output.writeAsBytesSync(ZipEncoder().encode(archive));
  stdout.writeln('Bundled PRTS player: ${output.lengthSync()} bytes');
}

import 'package:flutter/foundation.dart';
import 'download_task.dart';

final downloadService = AppDownloads();

class AppDownloads extends ChangeNotifier {
  bool get supported => false;
  List<ChapterDownload> get tasks => const [];
  int get storedBytes => 0;
  String? get error => null;
  Future<void> init() async {}
  ChapterDownload? taskFor(String id) => null;
  Future<void> start(String id, String title) async {}
  Future<void> startStory(
    String id,
    String title,
    Map<String, String> chapters,
  ) async {}
  Future<void> pause(String id) async {}
  Future<void> remove(String id) async {}
}

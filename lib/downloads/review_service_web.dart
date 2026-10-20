import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

final reviewAssets = ReviewAssetService();

/// Web remains online; native persistent download settings are not shown.
class ReviewAssetService extends ChangeNotifier {
  bool get supported => false;
  String? get revision => null;
  String? get error => null;
  bool get checking => false;
  bool get running => false;
  bool get clearing => false;
  String get state => 'idle';
  String? get selection => null;
  int get storedBytes => 0;
  int get totalBytes => 0;
  int get selectedBytes => 0;
  int get downloadedBytes => 0;
  int get completeCount => 0;
  int get totalCount => 0;
  int get activeBytes => 0;
  int get activeTotalBytes => 0;
  double get progress => 0;
  Future<void> init() async {}
  Future<void> checkForUpdates() async {}
  Future<dynamic> json(String url) async => null;
  Future<String?> localPath(String url) async => null;
  ImageProvider image(String url) => NetworkImage(url);
  Future<void> start(String scope) async {}
  Future<void> pause() async {}
  Future<void> clear() async {}
}

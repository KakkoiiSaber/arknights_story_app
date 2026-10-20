enum DownloadState { preparing, queued, downloading, paused, complete, failed }

class ChapterDownload {
  ChapterDownload({
    required this.id,
    required this.title,
    this.state = DownloadState.queued,
    List<String>? urls,
    List<String>? scripts,
    Map<String, String>? scriptTitles,
    this.manifestDone = 0,
    this.done = 0,
    this.bytes = 0,
    this.error,
  }) : urls = urls ?? [],
       scripts = scripts ?? [id],
       scriptTitles = scriptTitles ?? {};
  final String id;
  final String title;
  DownloadState state;
  List<String> urls;
  final List<String> scripts;
  final Map<String, String> scriptTitles;
  int manifestDone;
  int done;
  int bytes;
  int currentBytes = 0;
  int? currentTotal;
  String? error;
  double? get progress => urls.isEmpty ? null : done / urls.length;
  bool get active =>
      state == DownloadState.downloading ||
      state == DownloadState.preparing ||
      state == DownloadState.queued;
  String get label => switch (state) {
    DownloadState.preparing => '正在解析资源',
    DownloadState.queued => '等待下载',
    DownloadState.downloading => '下载中',
    DownloadState.paused => '已暂停',
    DownloadState.complete => '已下载',
    DownloadState.failed => '下载失败',
  };
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'state': state.name,
    'urls': urls,
    'scripts': scripts,
    'scriptTitles': scriptTitles,
    'manifestDone': manifestDone,
    'done': done,
    'bytes': bytes,
    'error': error,
  };
  factory ChapterDownload.fromJson(Map<String, dynamic> json) {
    final task = ChapterDownload(
      id: json['id'] as String,
      title: json['title'] as String,
      state: DownloadState.values.byName(json['state'] as String),
      done: json['done'] as int? ?? 0,
      bytes: json['bytes'] as int? ?? 0,
      error: json['error'] as String?,
      scripts: json['scripts'] is List
          ? List<String>.from(json['scripts'] as List)
          : null,
      scriptTitles: json['scriptTitles'] is Map
          ? Map<String, String>.from(json['scriptTitles'] as Map)
          : null,
      manifestDone:
          json['manifestDone'] as int? ??
          ((json['urls'] as List?)?.isNotEmpty == true ? 1 : 0),
    );
    task.urls = List<String>.from(json['urls'] as List? ?? []);
    return task;
  }
}

String downloadSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

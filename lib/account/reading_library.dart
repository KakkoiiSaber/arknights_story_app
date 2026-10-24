import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../settings/reader_settings.dart';
import 'library_storage_native.dart'
    if (dart.library.js_interop) 'library_storage_web.dart'
    as storage;

/// Script paths, rather than CDN URLs, identify a chapter across platforms.
String chapterKey(String source) {
  final uri = Uri.tryParse(source);
  var path = uri?.path ?? source;
  const prefix = '/gamedata/story/';
  final marker = path.indexOf(prefix);
  if (marker >= 0) path = path.substring(marker + prefix.length);
  return path
      .replaceFirst(RegExp(r'^/+'), '')
      .replaceFirst(RegExp(r'\.txt$'), '');
}

class LibraryRecord {
  LibraryRecord(
    this.kind,
    this.key,
    this.value, {
    this.revision = 0,
    this.dirty = false,
    this.edit = 0,
  });
  final String kind;
  final String key;
  Map<String, dynamic> value;
  int revision;
  bool dirty;
  int edit;
  String get id => '$kind:$key';
  Map<String, dynamic> toJson() => {
    'kind': kind,
    'key': key,
    'value': value,
    'revision': revision,
    'dirty': dirty,
    'edit': edit,
  };
  Map<String, dynamic> mutation() => {
    'kind': kind,
    'key': key,
    'value': value,
    'base_revision': revision,
  };
  static LibraryRecord fromJson(Map value) => LibraryRecord(
    value['kind'] as String,
    value['key'] as String,
    Map<String, dynamic>.from(value['value'] as Map),
    revision: (value['revision'] as num?)?.toInt() ?? 0,
    dirty: value['dirty'] == true,
    edit: (value['edit'] as num?)?.toInt() ?? 0,
  );
}

Map<String, dynamic> mergeChapter(
  Map<String, dynamic> remote,
  Map<String, dynamic> local,
) => {
  ...remote,
  'completed': remote['completed'] == true || local['completed'] == true,
  'skipped': remote['skipped'] == true || local['skipped'] == true,
  if (remote['scriptHash'] == local['scriptHash'])
    'furthest':
        ((remote['furthest'] as num?) ?? 0) > ((local['furthest'] as num?) ?? 0)
        ? remote['furthest']
        : local['furthest'],
};

final readingLibrary = ReadingLibrary(settings: readerSettings);

/// Local-first, account-isolated records. Remote revisions provide optimistic
/// concurrency; a stale offline device never replaces a newer resume position.
class ReadingLibrary extends ChangeNotifier {
  ReadingLibrary({
    required this.settings,
    Future<String?> Function()? read,
    Future<void> Function(String)? write,
  }) : _read = read ?? storage.read,
       _write = write ?? storage.write;
  final ReaderSettings settings;
  final Future<String?> Function() _read;
  final Future<void> Function(String) _write;
  final Map<String, Map<String, LibraryRecord>> _scopes = {};
  final Map<String, List<String>> _catalog = {};
  final Map<String, String> _guestImports = {};
  int? totalFor(String story) =>
      _catalog[story]?.length ??
      (resume(story)?['chapterCount'] as num?)?.toInt();
  void registerStory(String story, Iterable<String> scripts) {
    final ids = scripts.map(chapterKey).toSet().toList();
    if (listEquals(_catalog[story], ids)) return;
    _catalog[story] = ids;
    _changed();
  }

  String _scope = 'guest';
  String get scope => _scope;
  Map<String, LibraryRecord> get _records =>
      _scopes.putIfAbsent(_scope, () => {});
  Future<void> _saving = Future.value();
  bool _writing = false;
  String? _pendingWrite;
  Future<void>? _initializing;
  bool _applying = false;
  String? saveError;
  Map<String, Object> _lastSettings = {};
  Iterable<LibraryRecord> get records => _records.values;
  bool get hasPending => records.any((record) => record.dirty);
  bool get hasGuestData =>
      _scopes['guest']?.values.any(
        (r) =>
            r.kind != 'setting' ||
            r.value['value'] !=
                const {
                  'doctorName': '博士',
                  'fontScale': 1,
                  'typingIntervalMs': 40,
                }[r.key],
      ) ==
      true;
  String get _guestSignature =>
      jsonEncode(_scopes['guest']?.values.map((r) => r.toJson()).toList());
  bool get needsGuestMerge =>
      _scope != 'guest' &&
      hasGuestData &&
      _guestImports[_scope] != _guestSignature;
  LibraryRecord? getRecord(String kind, String key) => _records['$kind:$key'];
  Map<String, dynamic>? chapter(String script) =>
      getRecord('chapter', chapterKey(script))?.value;
  Map<String, dynamic>? resume(String story) =>
      getRecord('resume', story)?.value;
  Map<String, dynamic>? get latestResume {
    final list = records.where((r) => r.kind == 'resume').toList()
      ..sort(
        (a, b) => '${b.value['readAt']}'.compareTo('${a.value['readAt']}'),
      );
    return list.isEmpty
        ? null
        : {...list.first.value, 'storyId': list.first.key};
  }

  Future<void> init() => _initializing ??= _load();
  Future<void> _load() async {
    String? text;
    try {
      text = await _read();
    } catch (_) {
      saveError = '暂时无法读取本地存档，阅读仍然可用。';
    }
    if (text != null) {
      try {
        final decoded = jsonDecode(text) as Map;
        if (decoded['guestImports'] is Map) {
          _guestImports.addAll(
            Map<String, String>.from(decoded['guestImports'] as Map),
          );
        }
        if (decoded['catalog'] is Map) {
          for (final e in (decoded['catalog'] as Map).entries) {
            _catalog[e.key as String] = (e.value as List).cast<String>();
          }
        }
        for (final entry in (decoded['scopes'] as Map).entries) {
          final target = <String, LibraryRecord>{};
          for (final item in entry.value as List) {
            final record = LibraryRecord.fromJson(item as Map);
            target[record.id] = record;
          }
          _scopes[entry.key as String] = target;
        }
      } catch (_) {
        saveError = '本地阅读记录损坏，无法恢复。';
      }
    }
    if (_scopes.isEmpty) {
      for (final entry in settings.toJson().entries) {
        final r = LibraryRecord('setting', entry.key, {
          'value': entry.value,
        }, dirty: true);
        _records[r.id] = r;
      }
    }
    _applySettings();
    settings.addListener(_settingsChanged);
  }

  void _applySettings() {
    _applying = true;
    final values = <String, Object>{
      'doctorName': '博士',
      'fontScale': 1.0,
      'typingIntervalMs': 40,
      for (final r in records.where((r) => r.kind == 'setting'))
        r.key: r.value['value'] as Object,
    };
    if (mapEquals(settings.toJson(), values)) {
      _applying = false;
      _lastSettings = values;
      return;
    }
    settings.apply(values);
    _lastSettings = settings.toJson();
    _applying = false;
  }

  void _settingsChanged() {
    if (_applying) return;
    final next = settings.toJson();
    var changed = false;
    for (final entry in next.entries) {
      if (_lastSettings[entry.key] != entry.value) {
        _put('setting', entry.key, {'value': entry.value});
        changed = true;
      }
    }
    _lastSettings = next;
    if (changed) _changed();
  }

  void _put(String kind, String key, Map<String, dynamic> value) {
    final old = getRecord(kind, key);
    _records['$kind:$key'] = LibraryRecord(
      kind,
      key,
      value,
      revision: old?.revision ?? 0,
      dirty: true,
      edit: (old?.edit ?? 0) + 1,
    );
  }

  Future<void> switchAccount(String? userId) async {
    _scope = userId ?? 'guest';
    _applySettings();
    notifyListeners();
    await persist();
  }

  Future<void> mergeGuest({required bool useLocalSettings}) async {
    if (_scope == 'guest') return;
    for (final r in _scopes['guest']?.values ?? <LibraryRecord>[]) {
      final old = getRecord(r.kind, r.key);
      if (r.kind == 'setting' && !useLocalSettings && old != null) continue;
      final value = r.kind == 'chapter' && old != null
          ? mergeChapter(old.value, r.value)
          : old != null && r.kind == 'resume'
          ? old.value
          : r.value;
      _put(r.kind, r.key, Map<String, dynamic>.from(value));
    }
    _applySettings();
    _guestImports[_scope] = _guestSignature;
    _changed();
    await persist();
  }

  /// Both Web and WebView use this validated bridge payload.
  void recordProgress(Map payload) {
    final script = payload['chapterId'];
    final story = payload['storyId'];
    if (script is! String ||
        script.isEmpty ||
        script.length > 512 ||
        story is! String ||
        story.isEmpty ||
        story.length > 256) {
      return;
    }
    final key = chapterKey(script);
    final old = chapter(key) ?? {};
    final line = payload['line'];
    final total = payload['total'];
    if (line is! num ||
        !line.isFinite ||
        line < 0 ||
        line > 1000000 ||
        total is! num ||
        !total.isFinite ||
        total < 0 ||
        total > 1000000) {
      return;
    }
    final hash = payload['scriptHash'];
    if (hash is! String || hash.length > 128) return;
    final choices = payload['choices'] is List
        ? (payload['choices'] as List)
              .whereType<Map>()
              .where((c) => c['decisionId'] is int && c['optionIndex'] is int)
              .take(1000)
              .map(
                (c) => {
                  'decisionId': c['decisionId'],
                  'optionIndex': c['optionIndex'],
                },
              )
              .toList()
        : [];
    final fraction = total == 0 ? 0.0 : (line / total).clamp(0.0, 1.0);
    final now = DateTime.now().toUtc().toIso8601String();
    _put('chapter', key, {
      'storyId': story,
      'chapterId': key,
      'title': '${payload['title'] ?? ''}'.substring(
        0,
        '${payload['title'] ?? ''}'.length.clamp(0, 512),
      ),
      'line': line.toInt(),
      'total': total.toInt(),
      'choices': choices,
      'scriptHash': hash,
      'readAt': now,
      'completed': old['completed'] == true || payload['completed'] == true,
      'atEnd': payload['atEnd'] == true || payload['completed'] == true,
      'skipped': old['skipped'] == true || payload['skipped'] == true,
      'furthest':
          old['scriptHash'] == hash &&
              ((old['furthest'] as num?) ?? 0) > fraction
          ? old['furthest']
          : fraction,
    });
    // Completed sections stay resumable until the next section really opens.
    _put('resume', story, {
      'chapterId': key,
      'title': payload['title'],
      'readAt': now,
      if (payload['chapterCount'] is int)
        'chapterCount': (payload['chapterCount'] as int).clamp(1, 100000),
    });
    _changed();
  }

  int completedFor(String story) => records
      .where(
        (r) =>
            r.kind == 'chapter' &&
            r.value['storyId'] == story &&
            r.value['completed'] == true &&
            (_catalog[story]?.contains(r.key) ?? true),
      )
      .length;

  Map<String, dynamic> playerCheckpoints() => {
    for (final r in records.where((r) => r.kind == 'chapter')) r.key: r.value,
  };

  /// Pull never overwrites pending edits. Acknowledgements compare edit numbers
  /// so edits made while a request is in flight remain queued.
  void receive(List<Map<String, dynamic>> rows) {
    for (final row in rows) {
      final remote = LibraryRecord.fromJson(row);
      final old = _records[remote.id];
      if (old?.dirty != true) _records[remote.id] = remote;
    }
    _applySettings();
    _changed();
  }

  void acknowledge(Map<String, dynamic> row, int sentEdit) {
    final remote = LibraryRecord.fromJson(row);
    final local = _records[remote.id];
    if (local == null) return;
    if (local.edit != sentEdit) {
      local.revision = remote.revision;
    } else if (row['conflict'] == true && local.kind == 'chapter') {
      final merged = mergeChapter(remote.value, local.value);
      _records[remote.id] = LibraryRecord(
        remote.kind,
        remote.key,
        merged,
        revision: remote.revision,
        dirty: jsonEncode(merged) != jsonEncode(remote.value),
        edit: local.edit + 1,
      );
    } else {
      _records[remote.id] = remote;
    }
    _applySettings();
    _changed();
  }

  void _changed() {
    notifyListeners();
    unawaited(persist());
  }

  Future<void> persist() {
    final encoded = jsonEncode({
      'version': 1,
      'catalog': _catalog,
      'guestImports': _guestImports,
      'scopes': {
        for (final scope in _scopes.entries)
          scope.key: scope.value.values.map((r) => r.toJson()).toList(),
      },
    });
    _pendingWrite = encoded;
    if (!_writing) {
      _writing = true;
      _saving = _drainWrites();
    }
    return _saving;
  }

  Future<void> _drainWrites() async {
    while (_pendingWrite != null) {
      final encoded = _pendingWrite!;
      _pendingWrite = null;
      try {
        await _write(encoded);
        saveError = null;
      } catch (_) {
        saveError = '阅读记录暂时无法写入本机，请检查存储空间。';
      }
    }
    _writing = false;
  }

  @override
  void dispose() {
    settings.removeListener(_settingsChanged);
    super.dispose();
  }
}

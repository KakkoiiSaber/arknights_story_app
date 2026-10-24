import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'reader_storage_native.dart'
    if (dart.library.js_interop) 'reader_storage_web.dart'
    as storage;

final readerSettings = ReaderSettings();

class ReaderSettings extends ChangeNotifier {
  String doctorName = '博士';
  double fontScale = 1;
  int typingIntervalMs = 40;
  Future<void>? _initializing;
  Future<void> _saving = Future.value();
  String? saveError;

  Map<String, Object> toJson() => {
    'doctorName': doctorName,
    'fontScale': fontScale,
    'typingIntervalMs': typingIntervalMs,
  };

  Future<void> init() => _initializing ??= _load();
  Future<void> _load() async {
    try {
      final value = await storage.read();
      if (value != null) apply(jsonDecode(value));
    } catch (_) {
      // Missing, unavailable or corrupt local settings use readable defaults.
    }
  }

  void apply(dynamic value) {
    if (value is! Map) return;
    final name = value['doctorName'];
    doctorName = name is String && name.trim().isNotEmpty
        ? String.fromCharCodes(name.trim().runes.take(32))
        : '博士';
    final scale = value['fontScale'];
    fontScale = scale is num && scale.isFinite
        ? scale.toDouble().clamp(0.8, 1.4)
        : 1;
    final delay = value['typingIntervalMs'];
    typingIntervalMs = delay is num && delay.isFinite
        ? delay.round().clamp(0, 100)
        : 40;
    notifyListeners();
  }

  Future<void> update({String? name, double? scale, int? interval}) async {
    apply({
      ...toJson(),
      if (name != null) 'doctorName': name,
      if (scale != null) 'fontScale': scale,
      if (interval != null) 'typingIntervalMs': interval,
    });
    await persist();
  }

  Future<void> persist() async {
    final encoded = jsonEncode(toJson());
    _saving = _saving.then((_) async {
      try {
        await storage.write(encoded);
        saveError = null;
      } catch (_) {
        saveError = '设置暂时无法保存，重启后可能恢复默认值。';
      }
      notifyListeners();
    });
    await _saving;
  }
}

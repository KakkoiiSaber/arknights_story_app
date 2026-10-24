import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'reading_library.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);
final accountService = AccountService(readingLibrary);

class AccountService extends ChangeNotifier {
  AccountService(this.library, {SupabaseClient? client}) : _client = client;
  final ReadingLibrary library;
  SupabaseClient? _client;
  StreamSubscription<AuthState>? _auth;
  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  int _epoch = 0;
  int _taskEpoch = 0;
  bool _taskPull = false;
  Future<void>? _syncTask;
  Future<void>? _initializing;
  bool syncing = false;
  bool ready = false;
  String? error;
  DateTime? lastSynced;
  bool get configured =>
      _client != null ||
      (supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty);
  User? get user => _client?.auth.currentUser;
  SupabaseClient get client => _client ?? (throw StateError('账户服务尚未配置或暂时不可用'));

  Future<void> init() {
    if (ready) return Future.value();
    return _initializing ??= _initialize().whenComplete(
      () => _initializing = null,
    );
  }

  Future<void> _initialize() async {
    if (!configured || ready) return;
    try {
      if (_client == null) {
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabasePublishableKey,
        );
        _client = Supabase.instance.client;
      }
      _auth = client.auth.onAuthStateChange.listen(
        (state) {
          if (state.event == AuthChangeEvent.signedOut ||
              state.session?.user.id != library.scope) {
            unawaited(_selectUser(state.session?.user.id));
          }
        },
        onError: (Object _) {
          error = '登录状态刷新失败，请重新登录。';
          notifyListeners();
        },
      );
      await _selectUser(user?.id);
      ready = true;
      _timer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (library.hasPending) unawaited(sync(pull: false));
      });
      _lifecycle = AppLifecycleListener(
        onResume: () => unawaited(sync()),
        onPause: () {
          unawaited(library.persist());
          unawaited(sync());
        },
      );
    } catch (_) {
      error = '账户服务连接失败，可以继续离线阅读。';
    }
    notifyListeners();
  }

  Future<void> _selectUser(String? id) async {
    final epoch = ++_epoch;
    await library.switchAccount(id);
    lastSynced = null;
    error = null;
    notifyListeners();
    if (id != null && epoch == _epoch) await sync();
  }

  Future<void> ensureCurrentUser() async {
    if (user != null && library.scope != user!.id) {
      await _selectUser(user!.id);
    } else {
      await sync();
    }
  }

  Future<void> signOut() async {
    await sync();
    await client.auth.signOut(scope: SignOutScope.local);
    if (library.scope != 'guest') await _selectUser(null);
  }

  Future<void> sync({bool pull = true}) async {
    final pending = _syncTask;
    if (pending != null) {
      final epoch = _taskEpoch;
      final includedPull = _taskPull;
      await pending;
      if (epoch != _epoch || (pull && !includedPull)) await sync(pull: pull);
      return;
    }
    _taskEpoch = _epoch;
    _taskPull = pull;
    final task = _performSync(pull: pull);
    _syncTask = task;
    try {
      await task;
    } finally {
      if (identical(_syncTask, task)) _syncTask = null;
    }
  }

  Future<void> _performSync({required bool pull}) async {
    final id = user?.id;
    if (id == null || library.scope != id) return;
    final epoch = _epoch;
    syncing = true;
    error = null;
    notifyListeners();
    bool current() => epoch == _epoch && library.scope == id && user?.id == id;
    try {
      final rows = <Map<String, dynamic>>[];
      if (pull) {
        for (final entry in const {
          'setting': ('user_settings', 'setting_key'),
          'chapter': ('chapter_progress', 'chapter_id'),
          'resume': ('reading_resume', 'story_id'),
        }.entries) {
          for (var offset = 0; ; offset += 500) {
            final values = await client
                .from(entry.value.$1)
                .select()
                .eq('user_id', id)
                .order(entry.value.$2)
                .range(offset, offset + 499)
                .timeout(const Duration(seconds: 20));
            for (final row in values) {
              rows.add({
                'kind': entry.key,
                'key': row[entry.value.$2],
                'value': row['value'],
                'revision': row['revision'],
              });
            }
            if (values.length < 500) break;
          }
        }
      }
      if (!current()) return;
      library.receive(rows);
      // Bounded batches keep requests small for large reading libraries.
      final pending = library.records.where((r) => r.dirty).toList();
      for (var start = 0; start < pending.length; start += 50) {
        if (!current()) return;
        final batch = pending.skip(start).take(50).toList();
        final edits = {for (final r in batch) r.id: r.edit};
        final reply = await client
            .rpc(
              'sync_reading_records',
              params: {'mutations': batch.map((r) => r.mutation()).toList()},
            )
            .timeout(const Duration(seconds: 25));
        if (!current()) return;
        for (final item in reply as List) {
          final row = Map<String, dynamic>.from(item as Map);
          final edit = edits['${row['kind']}:${row['key']}'];
          if (edit != null) library.acknowledge(row, edit);
        }
      }
      if (current()) {
        lastSynced = DateTime.now();
        await library.persist();
      }
    } catch (failure, stack) {
      debugPrint('Reading sync failed (${failure.runtimeType})');
      debugPrintStack(stackTrace: stack);
      if (current()) error = '暂时无法同步，记录已保存在本机，联网后会重试。';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _auth?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }
}

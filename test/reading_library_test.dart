import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:arknights_story_app/account/reading_library.dart';
import 'package:arknights_story_app/settings/reader_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ReaderSettings settings;
  late ReadingLibrary library;
  String? saved;
  setUp(() async {
    saved = null;
    settings = ReaderSettings();
    library = ReadingLibrary(
      settings: settings,
      read: () async => saved,
      write: (v) async {
        saved = v;
      },
    );
    await library.init();
  });
  tearDown(() {
    library.dispose();
    settings.dispose();
  });
  Map<String, dynamic> progress({
    int line = 20,
    bool done = false,
    String hash = 'v1',
  }) => {
    'storyId': 'main_0',
    'chapterId': 'obt/main/a',
    'title': 'A',
    'line': line,
    'total': 100,
    'choices': [
      {'decisionId': 4, 'optionIndex': 1},
    ],
    'scriptHash': hash,
    'completed': done,
  };
  test('canonical ID survives resource host changes', () {
    expect(
      chapterKey(
        'https://raw.githubusercontent.com/Kengxxiao/ArknightsGameData/master/zh_CN/gamedata/story/obt/main/a.txt',
      ),
      'obt/main/a',
    );
    expect(chapterKey('obt/main/a.txt'), 'obt/main/a');
  });
  test(
    'completion and furthest progress survive rereading, position can go back',
    () {
      library.recordProgress(progress(line: 100, done: true));
      library.recordProgress(progress(line: 10));
      expect(library.chapter('obt/main/a')!['completed'], true);
      expect(library.chapter('obt/main/a')!['furthest'], 1);
      expect(library.chapter('obt/main/a')!['line'], 10);
      expect(library.chapter('obt/main/a')!['atEnd'], false);
    },
  );
  test('accounts and guest settings remain isolated', () async {
    await settings.update(name: 'guest');
    library.recordProgress(progress());
    await library.switchAccount('alice');
    expect(library.chapter('obt/main/a'), null);
    await settings.update(name: 'Alice');
    await library.switchAccount('bob');
    expect(settings.doctorName, '博士');
    await library.switchAccount('alice');
    expect(settings.doctorName, 'Alice');
    await library.switchAccount(null);
    expect(settings.doctorName, 'guest');
    expect(library.chapter('obt/main/a')!['line'], 20);
  });
  test('guest import keeps cloud position and unions completion', () async {
    library.recordProgress(progress(done: true));
    await settings.update(name: 'local');
    await library.switchAccount('alice');
    library.receive([
      {
        'kind': 'chapter',
        'key': 'obt/main/a',
        'revision': 4,
        'value': {...progress(line: 60), 'furthest': 0.6},
      },
      {
        'kind': 'setting',
        'key': 'doctorName',
        'revision': 2,
        'value': {'value': 'cloud'},
      },
    ]);
    await library.mergeGuest(useLocalSettings: false);
    expect(settings.doctorName, 'cloud');
    expect(library.chapter('obt/main/a')!['line'], 60);
    expect(library.chapter('obt/main/a')!['completed'], true);
  });
  test(
    'stale-device acknowledgement keeps cloud bookmark and merges completed fact',
    () async {
      library.recordProgress(progress(done: true));
      final sent = library.getRecord('chapter', 'obt/main/a')!.edit;
      library.acknowledge({
        'kind': 'chapter',
        'key': 'obt/main/a',
        'revision': 9,
        'conflict': true,
        'value': {...progress(line: 80), 'furthest': 0.8},
      }, sent);
      expect(library.chapter('obt/main/a')!['line'], 80);
      expect(library.chapter('obt/main/a')!['completed'], true);
      expect(library.getRecord('chapter', 'obt/main/a')!.revision, 9);
      expect(library.getRecord('chapter', 'obt/main/a')!.dirty, true);
    },
  );
  test('edit while network request in flight stays queued', () {
    library.recordProgress(progress());
    final sent = library.getRecord('chapter', 'obt/main/a')!.edit;
    library.recordProgress(progress(line: 40));
    library.acknowledge({
      'kind': 'chapter',
      'key': 'obt/main/a',
      'revision': 1,
      'value': progress(),
    }, sent);
    expect(library.chapter('obt/main/a')!['line'], 40);
    expect(library.getRecord('chapter', 'obt/main/a')!.dirty, true);
    expect(library.getRecord('chapter', 'obt/main/a')!.revision, 1);
  });
  test('pull does not overwrite dirty local changes', () {
    library.recordProgress(progress(line: 30));
    library.receive([
      {
        'kind': 'chapter',
        'key': 'obt/main/a',
        'revision': 2,
        'value': progress(line: 90),
      },
    ]);
    expect(library.chapter('obt/main/a')!['line'], 30);
  });
  test('restart restores selected account records and catalog', () async {
    library.registerStory('main_0', ['obt/main/a', 'obt/main/b']);
    await library.switchAccount('alice');
    library.recordProgress(progress());
    await library.persist();
    final otherSettings = ReaderSettings();
    final other = ReadingLibrary(
      settings: otherSettings,
      read: () async => saved,
      write: (v) async {},
    );
    await other.init();
    await other.switchAccount('alice');
    expect(other.chapter('obt/main/a')!['choices'], [
      {'decisionId': 4, 'optionIndex': 1},
    ]);
    expect(other.totalFor('main_0'), 2);
    expect(jsonDecode(saved!)['version'], 1);
    other.dispose();
    otherSettings.dispose();
  });
  test('invalid bridge payload does not create progress', () {
    library.recordProgress({...progress(), 'line': -1});
    expect(library.chapter('obt/main/a'), null);
  });
}

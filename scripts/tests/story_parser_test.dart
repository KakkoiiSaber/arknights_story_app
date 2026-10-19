// Dependency-free tests: dart scripts/tests/story_parser_test.dart [sample.txt ...]
import 'dart:io';

import '../../lib/story/story_script.dart';
import '../../lib/story/story_preview.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void main(List<String> samples) {
  const parser = StoryScriptParser();
  final events = parser.parse(
    '\uFEFF// comment\r\n\r\n'
    '[HEADER(key="demo", is_skippable=true)]\r\n'
    '[Character(name="char_002_amiya_1#5", focus=1)]\r\n'
    '[name="阿米娅"]  博士，{@nickname}。\r\n'
    '旁白 <i>原样保留</i>\r\n'
    '[Decision(options="甲;乙", values="1;2")]\r\n'
    '[Predicate(references="2")]\r\n'
    '[Dialog]\r\n',
  );
  check(events.length == 7, 'Blank/comment filtering');
  check(events.first.lineNumber == 3, 'Physical source line numbers');
  check(
    events.first.command == 'header' &&
        events.first.parameters['is_skippable'] == true,
    'Header and boolean',
  );
  check(
    events[1].parameters['focus'] == 1 &&
        events[1].parameters['name'] == 'char_002_amiya_1#5',
    'Character key',
  );
  check(
    events[2].kind == StoryEventKind.dialogue &&
        events[2].parameters['name'] == '阿米娅' &&
        events[2].text == '博士，{@nickname}。',
    'Dialogue and placeholders',
  );
  check(
    events[3].kind == StoryEventKind.narration &&
        events[3].text.contains('<i>'),
    'Narration and rich text',
  );
  check(
    events[4].parameters['values'] == '1;2' && events[5].command == 'predicate',
    'Preserve branch control',
  );
  check(!events.last.hasParameters, 'Parameterless Dialog is a clear command');

  final quoted = parser.parse(
    r'''[cHaRsLoT(slot='m',posfrom="0,0",name="a]b",duration=-0.5,Delay=2,expr=f(1,2),text="a=1, b=2\n\"yes\"\q")]''',
  ).single;
  check(quoted.command == 'charslot', 'Case-insensitive command');
  check(
    quoted.parameters['posfrom'] == '0,0' && quoted.parameters['name'] == 'a]b',
    'Quoted commas and closing brackets',
  );
  check(
    quoted.parameters['duration'] == -0.5 &&
        quoted.parameters['Delay'] == 2 &&
        !quoted.parameters.containsKey('delay'),
    'Typed values and case-sensitive parameter names',
  );
  check(quoted.parameters['expr'] == 'f(1,2)', 'Nested parentheses');
  check(quoted.parameters['text'] == 'a=1, b=2\n"yes"\\q', 'Escapes');

  final continued = parser.parse(
    '[Background(image="bg",\\\n'
    'fadetime=1)]\n[name="A (B)"] text',
  );
  check(
    continued.first.parameters['fadetime'] == 1 &&
        continued.first.raw.contains('\\\n') &&
        continued.last.lineNumber == 3,
    'Continuation retains raw source and physical numbering',
  );
  check(continued.last.parameters['name'] == 'A (B)', 'Parenthesized speaker');
  final dialogs = parser.parse(
    '[Dialog()]\n[imagegroup="a,b"] text\n[Name="X"] text',
  );
  check(
    dialogs.first.hasParameters &&
        dialogs[1].parameters['imagegroup'] == 'a,b' &&
        !dialogs.last.parameters.containsKey('name'),
    'Dialog tag forms',
  );

  final damaged = parser.parse(
    '[FutureEffect(foo="x",block=false)]\n'
    '[Character(name="bad)]\n'
    '[Delay(time=f(1,2)]\n'
    '[Delay(broken)]\n'
    '[name="A"] still readable',
  );
  check(
    damaged.first.command == 'futureeffect' &&
        damaged.first.parameters['block'] == false,
    'Unknown commands survive',
  );
  check(
    damaged.where((e) => e.kind == StoryEventKind.unparsed).length == 3 &&
        damaged[1].issue != null &&
        damaged.last.text == 'still readable',
    'Malformed lines are retained without losing later dialogue',
  );
  var immutable = false;
  try {
    events.first.parameters['key'] = 'changed';
  } on UnsupportedError {
    immutable = true;
  }
  check(immutable, 'Immutable event parameters');

  check(
    storyTxtPath(' /obt/main/demo.txt ') == 'obt/main/demo.txt' &&
        storyTxtPath('obt/main/demo.json') == 'obt/main/demo.txt' &&
        storyTxtPath('obt/main/demo') == 'obt/main/demo.txt',
    'TXT path migration',
  );
  for (final invalid in ['', '../bad', 'https://example.com/file', 'a?b']) {
    var rejected = false;
    try {
      storyTxtPath(invalid);
    } on ArgumentError {
      rejected = true;
    }
    check(rejected, 'Reject invalid path: $invalid');
  }
  final preview = parser.parse(
    '[Background(image="bg")]\n[Background]\n'
    '[Subtitle(text="hello")]\n[PlayMusic(key="\$escape_loop")]',
  );
  check(
    storyPreviewEvent(preview[0])['image'] == 'bg.png' &&
        storyPreviewEvent(preview[1])['image'] == null,
    'Preview images and clears',
  );
  check(
    storyPreviewEvent(preview[2])['content'] == 'hello' &&
        storyPreviewEvent(preview[3])['type'] == 'unsupported' &&
        preview[3].parameters['key'] == '\$escape_loop',
    'Preview has no audio side effects',
  );
  check(parser.parse(' \n// nothing').isEmpty, 'Empty script');
  for (final path in samples) {
    final parsed = parser.parse(File(path).readAsStringSync());
    final issues = parsed.where((e) => e.issue != null).toList();
    check(
      parsed.isNotEmpty && issues.isEmpty,
      '$path: ${issues.map((e) => '${e.lineNumber}: ${e.issue}').join(', ')}',
    );
    check(
      parsed.any((e) => e.kind == StoryEventKind.dialogue),
      '$path: no dialogue',
    );
    print('$path: ${parsed.length} events, no parse issues');
  }
  print('Story parser checks passed.');
}

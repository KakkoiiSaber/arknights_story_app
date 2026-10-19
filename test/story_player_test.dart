import 'package:flutter_test/flutter_test.dart';
import 'package:arknights_story_app/config/database.dart';
import 'package:arknights_story_app/story/story_script.dart';
import 'package:arknights_story_app/story/story_player.dart';

StoryPlayer play(String source) =>
    StoryPlayer(const StoryScriptParser().parse(source));

void main() {
  test('advance batches scene commands and pauses once per text', () {
    final player = play('''
[Background(image="bg_a")]
[Character(name="char_002_amiya_1#5")]
[name="阿米娅"] 第一段
[Delay(time=10)]
[PlayMusic(key="\$music")]
[Background(image="bg_b")]
[Character]
第二段旁白
[Image(image="cg_a")]
[name="博士"] 最后一段
''');
    expect(player.background, 'bg_a');
    expect(player.characters['m']?.name, 'char_002_amiya_1#5');
    expect(player.speaker, '阿米娅');
    expect(player.text, '第一段');
    player.advance();
    expect(player.background, 'bg_b');
    expect(player.characters, isEmpty);
    expect(player.speaker, isEmpty);
    expect(player.text, '第二段旁白');
    player.advance();
    expect(player.image, 'cg_a');
    expect(player.ended, isFalse);
    player.advance();
    expect(player.ended, isTrue);
    final line = player.lineNumber;
    player.advance();
    expect(player.lineNumber, line);
    player.restart();
    expect(player.background, 'bg_a');
    expect(player.image, isNull);
    expect(player.ended, isFalse);
    expect(player.text, '第一段');
  });

  test('single/dual character and charslot state is deterministic', () {
    final player = play('''
[Character(name="a",name2="b",focus=2)]
双人
[CharSlot(slot="middle",name="c",focus="m")]
中间
[CharSlot(slot="r",name="char_empty")]
[CharSlot(slot="m",ato=0)]
离场
[Character(name="d")]
单人
[Background]
[Image]
[Character]
清屏
''');
    expect(player.characters.keys, ['l', 'r']);
    expect(player.characters['l']!.dimmed, isTrue);
    expect(player.characters['r']!.dimmed, isFalse);
    player.advance();
    expect(player.characters.keys, ['l', 'r', 'm']);
    expect(player.characters['m']!.dimmed, isFalse);
    expect(player.characters['r']!.dimmed, isTrue);
    player.advance();
    expect(player.characters.keys, ['l']);
    player.advance();
    expect(player.characters.keys, ['m']);
    expect(player.characters['m']!.name, 'd');
    player.advance();
    expect(player.characters, isEmpty);
    expect(player.background, isNull);
    expect(player.image, isNull);
  });

  test('choices block advancing; predicates also gate scene commands', () {
    final player = play('''
[Decision(options="左;右",values="10;20")]
[Predicate(references="10")]
[Background(image="wrong")]
[Character(name="wrong")]
左侧文本
[Predicate(references="20")]
[Background(image="right")]
右侧文本
[Predicate]
汇合文本
''');
    expect(player.choices.map((c) => c.value), [10, 20]);
    player.advance();
    player.choose(3);
    expect(player.choices.length, 2);
    player.choose(1);
    expect(player.text, '右侧文本');
    expect(player.background, 'right');
    expect(player.characters, isEmpty);
    player.advance();
    expect(player.text, '汇合文本');
    player.advance();
    expect(player.ended, isTrue);
    player.restart();
    expect(player.choices.length, 2);
    expect(player.background, isNull);
    player.choose(0);
    expect(player.text, '左侧文本');
  });

  test('subtitle, empty text, unknown commands and malformed lines', () {
    final player = play(
      '[FutureCommand(foo=1)]\n[bad(]\n[Dialog]\n'
      '[name="A"]\n[Subtitle(text="字幕")]\n[EndTip]\n不会读取',
    );
    expect(player.text, '字幕');
    player.advance();
    expect(player.ended, isTrue);
    expect(player.text, '字幕');
    expect(play('// blank').ended, isTrue);
  });

  test('missing choice values fall back to zero and do not gate text', () {
    final player = play(
      '[Decision(options="A;B",values="1")]\n'
      '[Predicate(references="1")]\n正文',
    );
    player.choose(1);
    expect(player.text, '正文');
  });

  test('asset URLs encode expression keys and include default variants', () {
    final urls = Database.storyCharacterURLs('char_002_amiya_1#05');
    expect(urls.first, endsWith('char_002_amiya_1%235%241.png'));
    expect(urls.any((url) => url.endsWith('char_002_amiya_1%235.png')), isTrue);
    expect(Uri.parse(urls.first).fragment, isEmpty);
    expect(
      Database.storyCharacterURLs('char_130_doberm_ex').last,
      endsWith('char_130_doberm_ex.webp'),
    );
    expect(Database.storyBackgroundURL('bg_a.png'), endsWith('/bg_a.png'));
    expect(Database.storyImageURL('cg_a'), endsWith('/cg_a.png'));
  });
}

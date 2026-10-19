import 'story_script.dart';

class StoryCharacter {
  const StoryCharacter(this.name, {this.dimmed = false});
  final String name;
  final bool dimmed;
}

class StoryChoice {
  const StoryChoice(this.label, this.value);
  final String label;
  final int value;
}

/// Synchronous basic AVG runtime. Visual commands update scene state; only text,
/// choices and EOF pause execution. Widgets never execute script commands.
class StoryPlayer {
  StoryPlayer(Iterable<StoryEvent> events)
    : events = List.unmodifiable(events) {
    advance();
  }

  final List<StoryEvent> events;
  int _cursor = 0;
  int _selectedValue = 0;
  List<int>? _references;
  final Map<String, StoryCharacter> _characters = {};
  Map<String, StoryCharacter> get characters => Map.unmodifiable(_characters);
  List<StoryChoice> _choices = const [];
  List<StoryChoice> get choices => _choices;
  String? background;
  String? image;
  String speaker = '';
  String text = '';
  bool ended = false;
  int lineNumber = 0;

  void restart() {
    _cursor = 0;
    _selectedValue = 0;
    _references = null;
    _characters.clear();
    _choices = const [];
    background = null;
    image = null;
    speaker = '';
    text = '';
    ended = false;
    lineNumber = 0;
    advance();
  }

  void choose(int index) {
    if (index < 0 || index >= _choices.length) return;
    _selectedValue = _choices[index].value;
    _choices = const [];
    advance();
  }

  void advance() {
    if (ended || _choices.isNotEmpty) return;
    while (_cursor < events.length) {
      final event = events[_cursor++];
      final args = event.parameters;
      if (event.command == 'predicate') {
        _references = args.containsKey('references')
            ? _integers(args['references'])
            : null;
        continue;
      }
      if (_selectedValue != 0 &&
          _references != null &&
          _references!.isNotEmpty &&
          !_references!.contains(_selectedValue)) {
        continue;
      }
      lineNumber = event.lineNumber;
      if (event.kind == StoryEventKind.unparsed) continue;
      if (event.kind == StoryEventKind.dialogue ||
          event.kind == StoryEventKind.narration) {
        speaker = event.kind == StoryEventKind.dialogue
            ? (args['name'] ?? '').toString()
            : '';
        text = event.text;
        if (text.trim().isNotEmpty) return;
        continue;
      }
      switch (event.command) {
        case 'background':
          background = _asset(args['image']);
        case 'image':
          image = _asset(args['image']);
        case 'character':
          _characters.clear();
          final first = _asset(args['name']);
          final second = _asset(args['name2']);
          final focus = _integer(args['focus']);
          if (first != null) {
            _characters[second == null ? 'm' : 'l'] = StoryCharacter(
              first,
              dimmed: focus != 0 && focus != 1,
            );
          }
          if (second != null) {
            _characters['r'] = StoryCharacter(
              second,
              dimmed: focus != 0 && focus != 2,
            );
          }
        case 'charslot':
          _updateSlot(args);
        case 'dialog':
          speaker = '';
          text = event.text;
          if (text.trim().isNotEmpty) return;
        case 'subtitle':
          speaker = '';
          text = (args['text'] ?? event.text).toString();
          if (text.trim().isNotEmpty) return;
        case 'decision':
          _selectedValue = 0;
          _references = null;
          if (!args.containsKey('options')) continue;
          final labels = args['options'].toString().split(';');
          final values = _integers(args['values']);
          _choices = List.unmodifiable([
            for (var i = 0; i < labels.length; i++)
              StoryChoice(labels[i], i < values.length ? values[i] : 0),
          ]);
          speaker = '';
          text = '';
          return;
        case 'endtip':
          ended = true;
          return;
        default:
          // Retained in events for future animations, transforms and audio.
          break;
      }
    }
    ended = true;
  }

  void _updateSlot(Map<String, Object> args) {
    final slot = _slot(args['slot']);
    if (slot == null) return;
    if (args.containsKey('name')) {
      final name = _asset(args['name']);
      if (name == null) {
        _characters.remove(slot);
      } else {
        _characters[slot] = StoryCharacter(name);
      }
    }
    // Static endpoint of an explicit fade-out; interpolation is deferred.
    if (args.containsKey('ato') && _number(args['ato']) <= 0) {
      _characters.remove(slot);
    }
    if (args.containsKey('focus')) {
      final focus = args['focus'].toString().toLowerCase();
      final focused = focus.split(',').map(_slot).toSet();
      for (final entry in _characters.entries.toList()) {
        _characters[entry.key] = StoryCharacter(
          entry.value.name,
          dimmed: focus != 'all' && !focused.contains(entry.key),
        );
      }
    }
  }

  static String? _slot(Object? value) =>
      switch (value?.toString().toLowerCase().trim()) {
        'l' || 'left' => 'l',
        'm' || 'middle' || 'center' => 'm',
        'r' || 'right' => 'r',
        _ => null,
      };
  static String? _asset(Object? value) {
    final name = value?.toString().trim() ?? '';
    return name.isEmpty || name == 'char_empty' ? null : name;
  }

  static double _number(Object? value) => double.tryParse('$value') ?? 0;
  static int _integer(Object? value) => _number(value).toInt();
  static List<int> _integers(Object? value) =>
      value == null ? [] : value.toString().split(';').map(_integer).toList();
}

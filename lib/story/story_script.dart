enum StoryEventKind { command, dialogue, narration, unparsed }

/// Syntax only: no asset lookup, branching, delays or playback side effects.
class StoryEvent {
  StoryEvent({
    required this.kind,
    required this.lineNumber,
    required this.raw,
    this.command = '',
    Map<String, Object> parameters = const {},
    this.text = '',
    this.hasParameters = false,
    this.issue,
  }) : parameters = Map.unmodifiable(parameters);

  final StoryEventKind kind;
  final int lineNumber;
  final String raw;
  final String command;
  final Map<String, Object> parameters;
  final String text;
  // [Dialog] clears the panel; [Dialog()] has an explicit parameter block.
  final bool hasParameters;
  final String? issue;
}

/// Reads native AVG scripts, retaining commands even when no renderer knows them.
class StoryScriptParser {
  const StoryScriptParser();

  List<StoryEvent> parse(String source) {
    final lines = source
        .replaceFirst(RegExp(r'^\uFEFF'), '')
        .split(RegExp(r'\r\n?|\n'));
    final events = <StoryEvent>[];
    for (var i = 0; i < lines.length; i++) {
      final lineNumber = i + 1;
      final physical = <String>[lines[i]];
      var logical = lines[i];
      while (logical.endsWith('\\') && i + 1 < lines.length) {
        physical.add(lines[++i]);
        logical = logical.substring(0, logical.length - 1) + lines[i];
      }
      if (logical.trim().isEmpty || logical.trimLeft().startsWith('//')) {
        continue;
      }
      final raw = physical.join('\n');
      try {
        events.add(_parseLine(logical, raw, lineNumber));
      } on FormatException catch (error) {
        events.add(
          StoryEvent(
            kind: StoryEventKind.unparsed,
            lineNumber: lineNumber,
            raw: raw,
            text: logical,
            issue: error.message,
          ),
        );
      }
    }
    return List.unmodifiable(events);
  }

  StoryEvent _parseLine(String line, String raw, int lineNumber) {
    final trimmed = line.trimLeft();
    if (!trimmed.startsWith('[')) {
      return StoryEvent(
        kind: StoryEventKind.narration,
        lineNumber: lineNumber,
        raw: raw,
        text: line,
      );
    }
    final closing = _tagEnd(trimmed);
    if (closing < 0) throw const FormatException('Unclosed AVG tag');
    final inner = trimmed.substring(1, closing).trim();
    final text = trimmed.substring(closing + 1).trimLeft();
    final open = inner.indexOf('(');
    String command;
    String? arguments;
    // Assignment-style tags, including [name="..."] and [imagegroup="..."],
    // belong to Dialog. Parentheses inside quoted values are not command syntax.
    final equals = inner.indexOf('=');
    if (open >= 0 && (equals < 0 || open < equals)) {
      if (!inner.endsWith(')')) {
        throw const FormatException('Unclosed AVG parameter block');
      }
      command = inner.substring(0, open).trim().toLowerCase();
      arguments = inner.substring(open + 1, inner.length - 1);
    } else if (equals >= 0) {
      command = 'dialog';
      arguments = inner;
    } else {
      command = inner.toLowerCase();
    }
    if (command.isEmpty) throw const FormatException('Empty AVG command');
    final parameters = arguments == null
        ? <String, Object>{}
        : _parameters(arguments);
    return StoryEvent(
      kind: command == 'dialog' && arguments != null
          ? StoryEventKind.dialogue
          : StoryEventKind.command,
      lineNumber: lineNumber,
      raw: raw,
      command: command,
      parameters: parameters,
      text: text,
      hasParameters: arguments != null,
    );
  }

  int _tagEnd(String line) {
    String? quote;
    var escaped = false;
    for (var i = 1; i < line.length; i++) {
      final char = line[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (quote != null) {
        if (char == '\\') {
          escaped = true;
        } else if (char == quote) {
          quote = null;
        }
      } else if (char == '"' || char == "'") {
        quote = char;
      } else if (char == ']') {
        return i;
      }
    }
    return -1;
  }

  Map<String, Object> _parameters(String arguments) {
    final result = <String, Object>{};
    String? quote;
    var escaped = false;
    var depth = 0;
    var start = 0;
    void add(String part) {
      if (part.trim().isEmpty) return;
      final equals = part.indexOf('=');
      if (equals <= 0 || part.substring(0, equals).trim().isEmpty) {
        throw const FormatException('Expected key=value parameter');
      }
      result[part.substring(0, equals).trim()] = _value(
        part.substring(equals + 1).trim(),
      );
    }

    for (var i = 0; i < arguments.length; i++) {
      final char = arguments[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (quote != null) {
        if (char == '\\') {
          escaped = true;
        } else if (char == quote) {
          quote = null;
        }
      } else if (char == '"' || char == "'") {
        quote = char;
      } else if (char == '(') {
        depth++;
      } else if (char == ')') {
        depth--;
        if (depth < 0) throw const FormatException('Unbalanced parentheses');
      } else if (char == ',' && depth == 0) {
        add(arguments.substring(start, i));
        start = i + 1;
      }
    }
    if (quote != null || depth != 0) {
      throw const FormatException('Unclosed quote or parentheses');
    }
    add(arguments.substring(start));
    return result;
  }

  Object _value(String value) {
    if (value.startsWith('"') || value.startsWith("'")) {
      if (value.length < 2 || !value.endsWith(value[0])) {
        throw const FormatException('Unclosed string');
      }
      final quote = value[0];
      final output = StringBuffer();
      for (var i = 1; i < value.length - 1; i++) {
        var char = value[i];
        if (char == '\\' && i + 1 < value.length - 1) {
          char = value[++i];
          output.write(switch (char) {
            'n' => '\n',
            'r' => '\r',
            't' => '\t',
            '\\' => '\\',
            _ => char == quote ? char : '\\$char',
          });
        } else {
          output.write(char);
        }
      }
      return output.toString();
    }
    if (value == 'true') return true;
    if (value == 'false') return false;
    return num.tryParse(value) ?? value;
  }
}

/// Metadata paths are relative to gamedata/story, never arbitrary remote URLs.
String storyTxtPath(String path) {
  var relative = path
      .trim()
      .replaceAll('\\', '/')
      .replaceFirst(RegExp(r'^/+'), '');
  if (relative.isEmpty ||
      relative.contains(RegExp(r'[:?#]')) ||
      relative.split('/').any((part) => part == '..' || part == '.')) {
    throw ArgumentError.value(path, 'path', 'Invalid relative story path');
  }
  if (relative.endsWith('.json'))
    relative = relative.substring(0, relative.length - 5);
  if (!relative.endsWith('.txt')) relative = '$relative.txt';
  return relative.split('/').map(Uri.encodeComponent).join('/');
}

import 'story_models.dart';

class StoryParseResult {
  StoryParseResult({
    required this.lines,
    required this.errors,
    required this.actions,
  });

  final List<StoryLine> lines;
  final List<String> errors;
  final List<StoryAction> actions;
}

/// Lightweight parser for Arknights story `.txt` scripts.
/// The format can vary; this parser keeps things simple and
/// still debuggable by preserving raw directives.
class StoryParser {
  static StoryParseResult parse(String content) {
    final List<StoryLine> lines = [];
    final List<String> errors = [];
    final List<StoryAction> actions = [];
    String? currentSpeaker;

    final rawLines = content.split(RegExp(r'\r?\n'));
    for (var i = 0; i < rawLines.length; i++) {
      final raw = rawLines[i];
      var line = raw.trim();
      if (line.isEmpty) continue;

      // Skip comment-like lines
      if (line.startsWith('//') || line.startsWith('#')) continue;

      try {
        // Extract leading directives like [name="..."] [dialog] etc.
        final List<String> directives = [];
        while (line.startsWith('[')) {
          final end = line.indexOf(']');
          if (end == -1) break;
          directives.add(line.substring(1, end).trim());
          line = line.substring(end + 1).trimLeft();
        }

        for (final dir in directives) {
          final nameMatch =
              RegExp(r'^name\s*=\s*"([^"]+)"', caseSensitive: false).firstMatch(dir);
          if (nameMatch != null) {
            currentSpeaker = nameMatch.group(1);
            actions.add(
              StoryAction(
                type: StoryActionType.nameChange,
                payload: {'name': currentSpeaker},
                raw: raw,
              ),
            );
          }
          final action = _parseDirectiveToAction(dir, raw);
          if (action != null) actions.add(action);
        }

        if (line.isEmpty) {
          continue;
        }

        // Dialogue: Speaker: content style
        final colonIndex = line.indexOf(':');
        final isDialogue = colonIndex > 0 && colonIndex < line.length - 1 && !_looksLikeTimestamp(line);
        if (isDialogue) {
          final speaker = line.substring(0, colonIndex).trim();
          final text = line.substring(colonIndex + 1).trim();
          lines.add(
            StoryLine(
              type: StoryLineType.dialogue,
              speaker: speaker,
              text: text,
              raw: raw,
            ),
          );
          continue;
        }

        // Dialogue using current speaker (set via [name="..."])
        if (currentSpeaker != null) {
          lines.add(
            StoryLine(
              type: StoryLineType.dialogue,
              speaker: currentSpeaker,
              text: line,
              raw: raw,
            ),
          );
          continue;
        }

        // Default to narration.
        lines.add(
          StoryLine(
            type: StoryLineType.narration,
            text: line,
            raw: raw,
          ),
        );
      } catch (e) {
        errors.add('Line ${i + 1}: $e');
      }
    }

    return StoryParseResult(lines: lines, errors: errors, actions: actions);
  }

  static bool _looksLikeTimestamp(String line) {
    // Heuristic to avoid treating "00:12:34" as dialogue.
    final parts = line.split(':');
    if (parts.length != 3) return false;
    return parts.every((p) => int.tryParse(p) != null);
  }

  static StoryAction? _parseDirectiveToAction(String dir, String raw) {
    final lower = dir.toLowerCase();
    if (lower.startsWith('background')) {
      final image = _extractArg(dir, 'image');
      if (image != null) {
        return StoryAction(
          type: StoryActionType.background,
          payload: {'image': image},
          raw: raw,
        );
      }
    }
    if (lower.startsWith('playmusic')) {
      final intro = _extractArg(dir, 'intro');
      final loop = _extractArg(dir, 'key') ?? _extractArg(dir, 'loop');
      final volume = _extractArg(dir, 'volume');
      return StoryAction(
        type: StoryActionType.music,
        payload: {
          if (intro != null) 'intro': intro,
          if (loop != null) 'loop': loop,
          if (volume != null) 'volume': volume,
        },
        raw: raw,
      );
    }
    if (lower.startsWith('playsound')) {
      final key = _extractArg(dir, 'key');
      final volume = _extractArg(dir, 'volume');
      if (key != null) {
        return StoryAction(
          type: StoryActionType.sound,
          payload: {
            'key': key,
            if (volume != null) 'volume': volume,
          },
          raw: raw,
        );
      }
    }
    return StoryAction(
      type: StoryActionType.other,
      payload: {'raw': dir},
      raw: raw,
    );
  }

  static String? _extractArg(String directive, String key) {
    final regex =
        RegExp('$key\\s*=\\s*"([^"]+)"|$key\\s*=\\s*([^,\\s\\)]*)', caseSensitive: false);
    final match = regex.firstMatch(directive);
    if (match == null) return null;
    return (match.group(1) ?? match.group(2))?.trim();
  }
}

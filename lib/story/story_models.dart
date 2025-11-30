import '../config/database.dart';

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  final cleaned = value.toString().replaceAll(',', '').trim();
  return double.tryParse(cleaned);
}

bool? _asBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  final normalized = value.toString().replaceAll(',', '').trim().toLowerCase();
  if (normalized == 'true') return true;
  if (normalized == 'false') return false;
  return null;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  final parsed = int.tryParse(value.toString());
  return parsed ?? 0;
}

String? _cleanString(dynamic value) {
  if (value == null) return null;
  final trimmed = value.toString().trim();
  if (trimmed.isEmpty) return null;
  // Incoming data sometimes ends with a trailing comma.
  return trimmed.endsWith(',')
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;
}

List<String> _splitOptions(dynamic value) {
  final str = _cleanString(value);
  if (str == null || str.isEmpty) return const [];
  return str.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
}

class StoryEvent {
  StoryEvent({
    required this.id,
    required this.type,
    required this.data,
    this.raw,
    this.speaker,
    this.content,
    this.slot,
    this.character,
    this.image,
    this.background,
    this.introMusic,
    this.loopMusic,
    this.volume,
    this.loop,
    this.options = const [],
  });

  final int id;
  final String type;
  final Map<String, dynamic> data;
  final String? raw;
  final String? speaker;
  final String? content;
  final String? slot;
  final String? character;
  final String? image;
  final String? background;
  final String? introMusic;
  final String? loopMusic;
  final double? volume;
  final bool? loop;
  final List<String> options;

  String? get textContent => content;
  String? get backgroundUrl =>
      background == null ? null : Database.storyBackgroundPath + background!;
  String? get imageUrl => image == null ? null : Database.storyImagePath + image!;
  String? get characterUrl =>
      character == null ? null : Database.characterPath + character!;
  String? get introMusicUrl =>
      introMusic == null ? null : Database.storyMusicPath + introMusic!;
  String? get loopMusicUrl =>
      loopMusic == null ? null : Database.storyMusicPath + loopMusic!;

  bool get isTextual =>
      type == 'dialog' || type == 'narration' || type == 'subtitle';
  bool get isDecision => type == 'decision';

  factory StoryEvent.fromJson(Map<String, dynamic> json) {
    final map = Map<String, dynamic>.from(json);
    final type = map['type']?.toString() ?? 'unknown';

    String? background;
    String? image;
    String? character;
    String? slot;

    switch (type) {
      case 'background':
      case 'background_tween':
      case 'vertical_bg':
      case 'grid_background':
      case 'large_bg_tween':
        background = _cleanString(map['image']);
        break;
      case 'image':
      case 'image_tween':
      case 'character_cutin':
        image = _cleanString(map['image']);
        break;
      case 'charslot':
      case 'character':
        slot = _cleanString(map['slot']);
        character = _cleanString(map['name']);
        break;
      default:
        image = _cleanString(map['image']);
    }

    final speaker =
        type == 'dialog' ? _cleanString(map['speaker']) : _cleanString(map['name']);
    final content = _cleanString(map['content']) ?? _cleanString(map['text']);

    return StoryEvent(
      id: _asInt(map['id']),
      type: type,
      raw: _cleanString(map['raw']),
      speaker: speaker,
      content: content,
      slot: slot,
      character: character,
      image: image,
      background: background,
      introMusic: _cleanString(map['intro']),
      loopMusic: _cleanString(map['key']),
      volume: _asDouble(map['volume']),
      loop: _asBool(map['loop']),
      options: _splitOptions(map['options']),
      data: map,
    );
  }
}

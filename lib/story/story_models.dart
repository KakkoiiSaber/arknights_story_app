enum StoryLineType {
  dialogue,
  narration,
  directive,
}

class StoryLine {
  StoryLine({
    required this.type,
    required this.text,
    this.speaker,
    this.raw,
  });

  final StoryLineType type;
  final String text;
  final String? speaker;
  final String? raw;
}

enum StoryActionType {
  background,
  music,
  sound,
  nameChange,
  other,
}

class StoryAction {
  StoryAction({
    required this.type,
    required this.payload,
    this.raw,
  });

  final StoryActionType type;
  final Map<String, dynamic> payload;
  final String? raw;
}

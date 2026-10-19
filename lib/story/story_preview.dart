import 'story_script.dart';

/// Compatibility view for the scrolling reader, not a playback interpreter.
/// All branches are shown. Audio, timings and scene state remain in the source
/// events for a future runtime; no side effects occur while building widgets.
Map<String, dynamic> storyPreviewEvent(StoryEvent event) {
  if (event.kind == StoryEventKind.narration) {
    return {'type': 'narration', 'content': event.text};
  }
  if (event.kind == StoryEventKind.dialogue) {
    return {
      'type': 'dialog',
      'speaker': event.parameters['name'] ?? '',
      'content': event.text,
    };
  }
  final parameters = event.parameters;
  switch (event.command) {
    case 'background':
    case 'image':
      final image = parameters['image']?.toString();
      return {
        'type': event.command,
        'image': image == null || image.isEmpty
            ? null
            : Uri.encodeComponent(
                image.endsWith('.png') ? image : '$image.png',
              ),
      };
    case 'subtitle':
      return {'type': 'narration', 'content': parameters['text'] ?? event.text};
    case 'decision':
      return {'type': 'decision', 'options': parameters['options'] ?? ''};
    default:
      return {'type': 'unsupported'};
  }
}

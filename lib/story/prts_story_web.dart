import 'story_playlist.dart';
import 'dart:ui_web' as ui_web;
import 'dart:js_interop';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../settings/reader_settings.dart';
import '../account/reading_session.dart';

class PrtsStoryView extends StatefulWidget {
  const PrtsStoryView({
    super.key,
    required this.scriptURL,
    required this.title,
    this.playlist = const [],
    this.storyId = '',
  });
  final String scriptURL;
  final String title;
  final List<StoryPlaylistEntry> playlist;
  final String storyId;
  @override
  State<PrtsStoryView> createState() => _PrtsStoryViewState();
}

class _PrtsStoryViewState extends State<PrtsStoryView> {
  static int _nextView = 0;
  late final String _viewType;
  late final web.HTMLIFrameElement _frame;
  late final JSFunction _onMessage;

  late final ReadingSession _session;

  @override
  void initState() {
    super.initState();
    _session = ReadingSession(
      widget.scriptURL,
      widget.title,
      widget.storyId,
      widget.playlist,
    );
    _viewType = 'prts-story-${_nextView++}';
    final url = Uri.parse(web.document.baseURI)
        .resolve('prts-player/index.html')
        .replace(
          queryParameters: {
            'script': widget.scriptURL,
            'title': widget.title,
            'skin': 'archive',
            'preferences': jsonEncode(readerSettings.toJson()),
            'playlist': jsonEncode(
              widget.playlist.map((entry) => entry.toJson()).toList(),
            ),
          },
        );
    _frame = web.HTMLIFrameElement()
      ..src = url.toString()
      ..title = 'PRTS 剧情播放器'
      ..setAttribute('allow', 'autoplay')
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%';
    _onMessage = ((web.Event event) {
      final message = event as web.MessageEvent;
      if (message.origin == web.window.location.origin &&
          message.source == _frame.contentWindow &&
          message.data.isA<JSString>() &&
          mounted) {
        final data = (message.data as JSString).toDart;
        if (data == 'arkstory:exit') {
          Navigator.of(context).maybePop();
        } else if (data == 'arkstory:ready') {
          _syncPreferences();
        } else {
          try {
            final decoded = jsonDecode(data);
            if (decoded is Map &&
                decoded['type'] == 'arkstory:checkpoint-request' &&
                decoded['chapterId'] is String) {
              _frame.contentWindow?.postMessage(
                jsonEncode({
                  'type': 'arkstory:checkpoint',
                  'requestId': decoded['requestId'],
                  'value': _session.checkpoint(decoded['chapterId'] as String),
                }).toJS,
                web.window.location.origin.toJS,
              );
            } else if (decoded is Map &&
                decoded['type'] == 'arkstory:progress' &&
                decoded['value'] is Map) {
              _session.progress(decoded['value'] as Map);
            }
            if (decoded is Map &&
                decoded['type'] == 'arkstory:save-preferences' &&
                decoded['value'] is Map) {
              final value = decoded['value'] as Map;
              readerSettings.update(
                name: value['doctorName'] is String
                    ? value['doctorName'] as String
                    : null,
                scale: value['fontScale'] is num
                    ? (value['fontScale'] as num).toDouble()
                    : null,
                interval: value['typingIntervalMs'] is num
                    ? (value['typingIntervalMs'] as num).round()
                    : null,
              );
            }
          } catch (_) {
            /* Ignore messages outside the reader bridge. */
          }
        }
      }
    }).toJS;
    web.window.addEventListener('message', _onMessage);
    readerSettings.addListener(_syncPreferences);
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) => _frame);
  }

  void _syncPreferences() => _frame.contentWindow?.postMessage(
    jsonEncode({
      'type': 'arkstory:preferences',
      'value': readerSettings.toJson(),
    }).toJS,
    web.window.location.origin.toJS,
  );

  @override
  void dispose() {
    _session.close();
    readerSettings.removeListener(_syncPreferences);
    web.window.removeEventListener('message', _onMessage);
    // Navigate away to release upstream WebGL/audio even on Flutter's back route.
    _frame.src = 'about:blank';
    _frame.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SafeArea(child: HtmlElementView(viewType: _viewType));
}

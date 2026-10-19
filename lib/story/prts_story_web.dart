import 'dart:ui_web' as ui_web;
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class PrtsStoryView extends StatefulWidget {
  const PrtsStoryView({
    super.key,
    required this.scriptURL,
    required this.title,
  });
  final String scriptURL;
  final String title;
  @override
  State<PrtsStoryView> createState() => _PrtsStoryViewState();
}

class _PrtsStoryViewState extends State<PrtsStoryView> {
  static int _nextView = 0;
  late final String _viewType;
  late final web.HTMLIFrameElement _frame;
  late final JSFunction _onMessage;

  @override
  void initState() {
    super.initState();
    _viewType = 'prts-story-${_nextView++}';
    final url = Uri.parse(web.document.baseURI)
        .resolve('prts-player/index.html')
        .replace(
          queryParameters: {'script': widget.scriptURL, 'title': widget.title},
        );
    _frame = web.HTMLIFrameElement()
      ..src = url.toString()
      ..title = 'PRTS 剧情播放器'
      ..setAttribute('allow', 'autoplay; fullscreen')
      ..setAttribute('allowfullscreen', '')
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%';
    _onMessage = ((web.Event event) {
      final message = event as web.MessageEvent;
      if (message.origin == web.window.location.origin &&
          message.source == _frame.contentWindow &&
          message.data.isA<JSString>() &&
          (message.data as JSString).toDart == 'arkstory:exit' &&
          mounted) {
        Navigator.of(context).maybePop();
      }
    }).toJS;
    web.window.addEventListener('message', _onMessage);
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) => _frame);
  }

  @override
  void dispose() {
    web.window.removeEventListener('message', _onMessage);
    // Navigate away to release upstream WebGL/audio even on Flutter's back route.
    _frame.src = 'about:blank';
    _frame.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}

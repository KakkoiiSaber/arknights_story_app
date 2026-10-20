import 'story_playlist.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../downloads/native_service.dart';
import 'native_player_host.dart';
import '../settings/reader_settings.dart';

/// Native platforms run the same pinned PRTS build inside their system WebView.
class PrtsStoryView extends StatefulWidget {
  const PrtsStoryView({
    super.key,
    required this.scriptURL,
    required this.title,
    this.playlist = const [],
  });
  final String scriptURL;
  final String title;
  final List<StoryPlaylistEntry> playlist;
  @override
  State<PrtsStoryView> createState() => _PrtsStoryViewState();
}

class _PrtsStoryViewState extends State<PrtsStoryView> {
  late Future<NativePlayerHost> _host;
  String? _loadError;
  InAppWebViewController? _controller;
  @override
  void initState() {
    super.initState();
    _host = downloadService.playerHost();
    readerSettings.addListener(_syncPreferences);
  }

  void _syncPreferences() {
    _controller
        ?.evaluateJavascript(
          source:
              'globalThis.__arkstoryApplyPreferences?.(${jsonEncode(readerSettings.toJson())});',
        )
        .catchError((Object _) => null);
  }

  @override
  void dispose() {
    readerSettings.removeListener(_syncPreferences);
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: FutureBuilder<NativePlayerHost>(
        future: _host,
        builder: (context, snapshot) {
          if (snapshot.hasError || _loadError != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('播放器加载失败：${_loadError ?? snapshot.error}'),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('返回故事页'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final host = snapshot.data!;
          return InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri(
                host
                    .page('index.html', widget.scriptURL, title: widget.title)
                    .replace(
                      queryParameters: {
                        ...host
                            .page(
                              'index.html',
                              widget.scriptURL,
                              title: widget.title,
                            )
                            .queryParameters,
                        'preferences': jsonEncode(readerSettings.toJson()),
                        'playlist': jsonEncode(
                          widget.playlist
                              .map((entry) => entry.toJson())
                              .toList(),
                        ),
                      },
                    )
                    .toString(),
              ),
            ),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              useShouldOverrideUrlLoading: true,
            ),
            onWebViewCreated: (controller) {
              _controller = controller;
              controller.addJavaScriptHandler(
                handlerName: 'arkstory',
                callback: (args) async {
                  if (!mounted) return null;
                  final currentURL = await controller.getUrl();
                  if (!mounted) return null;
                  if (!context.mounted) return null;
                  if (currentURL?.origin != host.base.origin || args.isEmpty) {
                    return null;
                  }
                  if (args.first == 'exit') {
                    Navigator.of(context).maybePop();
                  } else if (args.first == 'preferences' &&
                      args.length > 1 &&
                      args[1] is Map) {
                    final value = args[1] as Map;
                    await readerSettings.update(
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
                    return readerSettings.saveError;
                  }
                  return null;
                },
              );
            },
            onLoadStop: (_, _) => _syncPreferences(),
            shouldOverrideUrlLoading: (_, action) async =>
                action.request.url?.origin == host.base.origin
                ? NavigationActionPolicy.ALLOW
                : NavigationActionPolicy.CANCEL,
            onReceivedError: (_, request, error) {
              if (request.isForMainFrame == true && mounted) {
                setState(() => _loadError = error.description);
              }
            },
          );
        },
      ),
    ),
  );
}

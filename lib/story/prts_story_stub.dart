import 'story_playlist.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../downloads/native_service.dart';
import 'native_player_host.dart';
import '../settings/reader_settings.dart';
import '../account/reading_session.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

/// Native platforms run the same pinned PRTS build inside their system WebView.
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
  late Future<NativePlayerHost> _host;
  String? _loadError;
  InAppWebViewController? _controller;
  late final AppLifecycleListener _lifecycle;
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
    _host = _prepareHost();
    _lifecycle = AppLifecycleListener(
      onResume: () async {
        if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
        await _activateAudio();
        if (!mounted) return;
        await _controller
            ?.evaluateJavascript(
              source: 'globalThis.__arkstoryResumeAudio?.();',
            )
            .catchError((Object _) => null);
      },
    );
    readerSettings.addListener(_syncPreferences);
  }

  Future<void> _activateAudio() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      // The outgoing audioplayers route deactivates AVAudioSession when its
      // last player stops. Hand ownership to the embedded story player.
      final session = await AudioSession.instance.timeout(
        const Duration(seconds: 5),
      );
      await session
          .configure(const AudioSessionConfiguration.music())
          .timeout(const Duration(seconds: 5));
      final active = await session
          .setActive(true)
          .timeout(const Duration(seconds: 5));
      if (!active) debugPrint('PRTS iOS audio session activation declined');
    } catch (error) {
      debugPrint('PRTS iOS audio session activation failed: $error');
    }
  }

  Future<NativePlayerHost> _prepareHost() async {
    final host = await downloadService.playerHost();
    if (mounted) await _activateAudio();
    return host;
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
    _session.close();
    _lifecycle.dispose();
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
                        'skin': 'archive',
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
                  if (args.first == 'checkpoint' &&
                      args.length > 1 &&
                      args[1] is String) {
                    return _session.checkpoint(args[1] as String);
                  } else if (args.first == 'progress' &&
                      args.length > 1 &&
                      args[1] is Map) {
                    _session.progress(args[1] as Map);
                  } else if (args.first == 'exit') {
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
            onLoadStop: (_, _) async {
              _syncPreferences();
              await _activateAudio();
              if (!mounted) return;
              await _controller
                  ?.evaluateJavascript(
                    source: 'globalThis.__arkstoryResumeAudio?.();',
                  )
                  .catchError((Object _) => null);
            },
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

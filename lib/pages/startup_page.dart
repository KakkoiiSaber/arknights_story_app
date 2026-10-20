import 'package:flutter/material.dart';
import '../config/archive_style.dart';

/// Paint before touching platform plugins so a slow plugin cannot hide startup.
class StartupPage extends StatefulWidget {
  const StartupPage({
    super.key,
    required this.initialize,
    required this.childBuilder,
  });
  final Future<void> Function(ValueChanged<String> status) initialize;
  final WidgetBuilder childBuilder;

  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage> {
  String _status = '正在启动';
  Object? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (!mounted) return;
    setState(() => _error = null);
    try {
      await widget.initialize((status) {
        if (mounted) setState(() => _status = status);
      });
      if (mounted) setState(() => _ready = true);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.childBuilder(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ARKSTORY',
                    style: TextStyle(
                      fontSize: 28,
                      letterSpacing: 5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (_error == null) ...[
                    const LinearProgressIndicator(minHeight: 2),
                    const SizedBox(height: 16),
                    Text(
                      _status,
                      style: const TextStyle(color: ArchiveStyle.muted),
                    ),
                  ] else ...[
                    Text(
                      '$_status失败',
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_error',
                      style: const TextStyle(
                        fontSize: 12,
                        color: ArchiveStyle.muted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _start,
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试启动'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/widgets.dart';

// Native platforms retain the Dart player until their WebView bridge is ready.
class PrtsStoryView extends StatelessWidget {
  const PrtsStoryView({
    super.key,
    required this.scriptURL,
    required this.title,
  });
  final String scriptURL;
  final String title;
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

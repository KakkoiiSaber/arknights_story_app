import 'package:flutter/material.dart';
import 'reader_settings.dart';

class ReaderSettingsPanel extends StatefulWidget {
  const ReaderSettingsPanel({super.key});
  @override
  State<ReaderSettingsPanel> createState() => _ReaderSettingsPanelState();
}

class _ReaderSettingsPanelState extends State<ReaderSettingsPanel> {
  late final _name = TextEditingController(text: readerSettings.doctorName);
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: readerSettings,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('阅读设置', style: TextStyle(fontSize: 21)),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          maxLength: 32,
          decoration: const InputDecoration(labelText: '博士名称', hintText: '博士'),
          onChanged: (value) => readerSettings.update(name: value),
        ),
        const SizedBox(height: 12),
        Text('文字字号  ${(readerSettings.fontScale * 100).round()}%'),
        Slider(
          value: readerSettings.fontScale,
          min: 0.8,
          max: 1.4,
          divisions: 6,
          onChanged: (value) => readerSettings.update(scale: value),
        ),
        Text(
          '文字显示速度  ${readerSettings.typingIntervalMs == 0 ? '即时显示' : '${readerSettings.typingIntervalMs} 毫秒／字'}',
        ),
        Slider(
          value: (100 - readerSettings.typingIntervalMs).toDouble(),
          min: 0,
          max: 100,
          divisions: 20,
          onChanged: (value) =>
              readerSettings.update(interval: 100 - value.round()),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text('慢'), Text('即时')],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            '${readerSettings.doctorName}，欢迎回来。',
            style: TextStyle(fontSize: 18 * readerSettings.fontScale),
          ),
        ),
        const Text(
          '适用于所有剧情。对白和人物名称字号立即生效，博士名称与显示速度从下一句起生效。',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        if (readerSettings.saveError != null)
          Text(
            readerSettings.saveError!,
            style: const TextStyle(color: Colors.orangeAccent),
          ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 20),
      ],
    ),
  );
}

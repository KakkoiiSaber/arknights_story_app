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
        const Text('阅读偏好', style: TextStyle(fontSize: 21)),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          maxLength: 32,
          decoration: const InputDecoration(labelText: '博士名称', hintText: '博士'),
          onChanged: (value) => readerSettings.update(name: value),
        ),
        const SizedBox(height: 12),
        Text('文字字号  ${(readerSettings.fontScale * 100).round()}%'),
        _SegmentSlider(
          value: readerSettings.fontScale,
          min: 0.8,
          max: 1.4,
          divisions: 6,
          onChanged: (value) => readerSettings.update(scale: value),
        ),
        Text(
          '文字显示速度  ${readerSettings.typingIntervalMs == 0 ? '即时显示' : '${readerSettings.typingIntervalMs} 毫秒／字'}',
        ),
        _SegmentSlider(
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

class _SegmentSlider extends StatelessWidget {
  const _SegmentSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });
  final double value, min, max;
  final int divisions;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: CustomPaint(
            painter: _Segments(
              divisions,
              ((value - min) / (max - min) * divisions).round(),
              Directionality.of(context),
            ),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 0,
            thumbShape: SliderComponentShape.noThumb,
            tickMarkShape: SliderTickMarkShape.noTickMark,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );
}

class _Segments extends CustomPainter {
  const _Segments(this.count, this.selected, this.direction);
  final int count, selected;
  final TextDirection direction;
  @override
  void paint(Canvas canvas, Size size) {
    if (direction == TextDirection.rtl) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final pitch = size.width / count;
    final y = size.height / 2;
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      paint.color = i < selected
          ? const Color(0xffa6b6b0)
          : const Color(0xff414948);
      canvas.drawRect(
        Rect.fromLTRB(i * pitch + 1, y - 2, (i + 1) * pitch - 1, y + 2),
        paint,
      );
    }
    paint.color = const Color(0xffe2e8e5);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(selected * pitch, y),
        width: 3,
        height: 12,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_Segments old) =>
      old.count != count ||
      old.selected != selected ||
      old.direction != direction;
}

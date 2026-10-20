import 'package:flutter/material.dart';

/// Native activity artwork can be split across adjacent textures.
class StoryBackground extends StatelessWidget {
  const StoryBackground({
    super.key,
    required this.images,
    this.aspectRatio = 16 / 9,
  });
  final List<ImageProvider> images;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.expand();
    const alignment = Alignment(-0.5, 0);
    if (images.length == 1) {
      return Image(
        image: images.single,
        fit: BoxFit.cover,
        alignment: alignment,
      );
    }
    return FittedBox(
      fit: BoxFit.cover,
      alignment: alignment,
      child: SizedBox(
        width: 1000 * aspectRatio,
        height: 1000,
        child: Row(
          children: [
            for (final image in images)
              Expanded(
                child: Image(image: image, fit: BoxFit.fill, height: 1000),
              ),
          ],
        ),
      ),
    );
  }
}

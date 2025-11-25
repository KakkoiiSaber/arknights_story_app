// this component is used to display a single story entry in a list
import 'package:flutter/material.dart';

class StoryEntry extends StatelessWidget {
  final String name;
  final ImageProvider? kvImage;
  final ImageProvider? titleImage;
  final VoidCallback onTap;
  final double? width;
  final double? height;

  const StoryEntry({
    super.key,
    required this.name,
    required this.kvImage,
    required this.titleImage,
    required this.onTap,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final double cardWidth = width ?? 250;
    final double cardHeight = height ?? 300;
    final double imageHeight = cardHeight - 48;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: cardHeight,
        width: cardWidth,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: imageHeight,
              width: cardWidth,
              child: ClipRRect(
                // borderRadius: BorderRadius.circular(8),
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        color: Color.fromARGB(88, 101, 97, 93),
                      ),
                      child: kvImage == null
                          ? const Icon(Icons.image)
                          : Transform.scale(
                              scale: 1.1,
                              child: Image(
                                image: kvImage!,
                                fit: BoxFit.fitHeight,
                                alignment: Alignment.center,
                              ),
                            ),
                    ),
                    if (titleImage != null)
                        Align(
                            alignment: Alignment.bottomCenter,
                            child: SizedBox(
                              height: 150, 
                              width: 200,               // constrain title image height
                              // width: double.infinity,    // optional: stretch across the card
                              child: Image(
                                image: titleImage!,
                                fit: BoxFit.contain,   // or BoxFit.contain / cover
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
            // const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              softWrap: false,
            ),
          ],
        ),
      ),
    );
  }
}

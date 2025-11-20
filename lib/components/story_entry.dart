// this component is used to display a single story entry in a list
import 'package:flutter/material.dart';

class StoryEntry extends StatelessWidget {
  final String name;
  final ImageProvider? kvImage;
  final ImageProvider? titleImage;
  final VoidCallback onTap;

  const StoryEntry({
    super.key,
    required this.name,
    required this.kvImage,
    required this.titleImage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 300,
        width: 250,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 250,
              width: 250,
              child: ClipRRect(
                // borderRadius: BorderRadius.circular(8),
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        // color: Colors.grey[800],
                        color: const Color.fromARGB(88, 101, 97, 93),
                        image: kvImage != null
                            ? DecorationImage(
                                image: kvImage!,
                                fit: BoxFit.fitHeight,
                                // fit: BoxFit.contain,
                              )
                            : null,
                      ),
                      child:
                          kvImage == null ? const Icon(Icons.image) : null,
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
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}



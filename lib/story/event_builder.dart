import 'package:flutter/material.dart';

import '../config/database.dart';

Widget storyImageContainer({
  String? imagePath,
  String? fadetime,
}) {
  if (imagePath == null || imagePath.isEmpty) return const SizedBox.shrink();

  final imageBox = SizedBox(
    width: double.infinity,
    child: Image.network(
      '${Database.storyImagePath}/$imagePath',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('storyImageContainer failed for ${Database.storyImagePath}/$imagePath: $error');
        return const SizedBox.shrink();
      },
    ),
  );

  if (fadetime != null) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: int.tryParse(fadetime) ?? 0),
      child: imageBox,
    );
  }
  return imageBox;
}

Widget storyBackgroundContainer({
  String? imagePath,
  String? fadetime,
}) {
  if (imagePath == null || imagePath.isEmpty) return const SizedBox.shrink();

  final imageBox = SizedBox(
    width: double.infinity,
    child: Image.network(
      '${Database.storyBackgroundPath}/$imagePath',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('storyBackgroundContainer failed for ${Database.storyBackgroundPath}/$imagePath: $error');
        return const SizedBox.shrink();
      },
    ),
  );

  if (fadetime != null) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: int.tryParse(fadetime) ?? 0),
      child: imageBox,
    );
  }
  return imageBox;
}

Widget storyCharacterContainer({
  required String name
  }) {
  return SizedBox(
    width: double.infinity,
    child: Image.network(
      '${Database.storyCharacterPath}/$name',
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('storyCharacterContainer failed for ${Database.storyCharacterPath}/$name: $error');
        return const SizedBox.shrink();
      },
    ),
  );
}

Widget dialogueContainer({
  String? speaker,
  required String content,
}) {
  return Container(
    padding: const EdgeInsets.all(8.0),
    color: const Color.fromARGB(0, 0, 0, 0),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (speaker != null && speaker.isNotEmpty) ...[
            const SizedBox(height: 12),
          Text(
            '$speaker :',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color.fromARGB(255, 168, 168, 168),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          content,
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
      ],
    ),
  );
}

Widget decisionContainer({
  required String options,
  String speaker = 'Dr. {@nickname}',
  List<String>? optionsList,
  required void Function(int) onOptionSelected,
}) {
  optionsList ??= options.split(";").toList();
  return Container(
    padding: const EdgeInsets.all(8.0),
    decoration: BoxDecoration(
      color: const Color.fromARGB(0, 0, 0, 0),
      borderRadius: BorderRadius.circular(0),
      // border: Border.all(color: Colors.white12),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
      Text(
            speaker,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color.fromARGB(255, 168, 168, 168),
            ),
        ),
        SizedBox(height: 8),
      ...optionsList
          .asMap()
          .entries
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(0),
                  ),
                ),
                onPressed: () => onOptionSelected(entry.key),
                child: Text(entry.value),
              ),
            ),
          ),
          ]
    ),
  );
}

Widget debugContainer({
  required String content,
}) {
  return Container(
    padding: const EdgeInsets.all(16.0),
    color: const Color.fromARGB(255, 118, 111, 111),
    child: Text(
      content,
      style: const TextStyle(fontSize: 16, color: Colors.white),
    ),
  );
}

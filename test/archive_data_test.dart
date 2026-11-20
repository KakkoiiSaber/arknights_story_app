import 'dart:convert';

import 'package:arknights_story_app/config/database.dart';
import 'package:arknights_story_app/utils/data_retriever.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'archive index, story detail and music resolve through the media catalog',
    () async {
      const cover = 'https://old.example/cover.png';
      final index = Database.storyMetaTablePath;
      final detail = Uri.parse(
        index,
      ).resolve('stories/special-variant.json').toString();
      final documents = {
        index: {
          'stories': [
            {
              'id': 'special',
              'kvImageId': cover,
              'detail': 'stories/special-variant.json',
            },
          ],
          'homeMusic': {'loop': 'music'},
        },
        Database.reviewManifestURL: {
          'resources': {
            cover: {'path': 'media/test/cover.png'},
            'music': {'path': 'media/home/loop.mp3'},
          },
        },
        detail: {
          'backgroundUrls': [cover],
          'audio': {'loop': 'music'},
        },
      };
      final hits = <String>[];
      final client = MockClient((request) async {
        final url = request.url.toString();
        hits.add(url);
        return http.Response(
          jsonEncode(documents[url]),
          documents.containsKey(url) ? 200 : 404,
        );
      });
      await http.runWithClient(() async {
        final results = await Future.wait([
          DataRetriever.getJsonFromURL(index),
          DataRetriever.getJsonFromURL(Database.gameMusicDataPath),
        ]);
        final coverUrl = '${Database.reviewDataURL}media/test/cover.png';
        final musicUrl = '${Database.reviewDataURL}media/home/loop.mp3';
        expect(results[0]['special']['kvImageId'], coverUrl);
        expect(results[1]['sys.ON_MUSIC.bg_void']['loop'], musicUrl);
        expect(Database.detailURL('special'), detail);
        final story = await DataRetriever.getJsonFromURL(detail);
        expect(story['backgroundUrls'], [coverUrl]);
        expect(story['audio']['loop'], musicUrl);
        expect(
          hits,
          unorderedEquals([index, Database.reviewManifestURL, detail]),
        );
      }, () => client);
    },
  );
}

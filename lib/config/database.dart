import 'config.dart';

class Database {
  // path to story review meta data, review info
  static String reviewDataURL =
      "https://raw.githubusercontent.com/KakkoiiSaber/arknights_story_data/main";

  static String storyMetaTablePath =
      "$reviewDataURL/assets/${Config.server}/story_meta_table.json";
  static String gameMusicDataPath =
      "$reviewDataURL/assets/${Config.server}/audio_data.json";
  static String reviewInfoPath =
      "$reviewDataURL/assets/${Config.server}/story_review_info/";

  // path to story review assets
  static const reviewAssetsURL =
      "https://raw.githubusercontent.com/KakkoiiSaber/arkdata/main";
  //story cover images
  static const kvImagePath =
      "$reviewAssetsURL/assets/torappu/dynamicassets/arts/ui/mixstory/kvs/";
  // story title images
  static const titleImagePath =
      "$reviewAssetsURL/assets/torappu/dynamicassets/arts/ui/mixstory/titles/";
  // story review background images
  static const backgroundPath =
      "$reviewAssetsURL/assets/torappu/dynamicassets/arts/ui/mixstory/retrobkgs/";
  // story review music assets
  static const gameMusicPath = "$reviewAssetsURL/assets/torappu/dynamicassets/";

  // path to story data
  static const storyDataURLCN =
      "https://raw.githubusercontent.com/Kengxxiao/ArknightsGameData/master";
  static const storyDataURLGlobal =
      "https://raw.githubusercontent.com/Kengxxiao/ArknightsGameData_YoStar/main";
  static String get storyContentURL =>
      Config.server == 'zh_CN' ? storyDataURLCN : storyDataURLGlobal;
  // Raw AVG scripts retain the .txt paths supplied by story review metadata.
  // The reader must fetch text and parse AVG commands instead of decoding JSON.
  static String get storyContentPath =>
      "$storyContentURL/${Config.server}/gamedata/story/";

  // path to story assets
  static const storyAssetsURL =
      "https://raw.githubusercontent.com/akgcc/arkdata/main";
  static String storyBackgroundPath =
      "$storyAssetsURL/assets/torappu/dynamicassets/avg/backgrounds";
  static String storyImagePath =
      "$storyAssetsURL/assets/torappu/dynamicassets/avg/images";
  static String storyMusicPath =
      "$storyAssetsURL/assets/torappu/dynamicassets/";
  static String storySoundPath =
      "$storyAssetsURL/assets/torappu/dynamicassets/";
  static String storyCharacterPath = "$storyAssetsURL/assets/avg/characters";
  // Cropped story portraits, separate from operator roster avatars.
  static const storyAvatarPath = "$storyAssetsURL/thumbs";

  // Script names may omit the default face/pose: char_002_amiya_1#5
  // corresponds to char_002_amiya_1#5$1 in the extracted assets.
  static String _storyCharacterKey(String name) {
    final match = RegExp(
      r'^([^#$]+)(?:#(\d+))?(?:\$(\d+))?$',
    ).firstMatch(name.trim().toLowerCase());
    if (match == null) {
      throw ArgumentError.value(name, 'name', 'Invalid AVG character key');
    }
    final face = int.parse(match.group(2) ?? '1');
    final pose = int.parse(match.group(3) ?? '1');
    return '${match.group(1)}#$face\$$pose';
  }

  // Encode the filename so '#' is sent to the server, not used as a fragment.
  // PNG is the verified format for the sample sprites; asset fallbacks belong
  // in the future resource resolver when handling other script characters.
  static String storyCharacterURL(String name) =>
      '$storyCharacterPath/${Uri.encodeComponent('${_storyCharacterKey(name)}.png')}';

  static String storyAvatarURL(String name) =>
      '$storyAvatarPath/${Uri.encodeComponent('${_storyCharacterKey(name)}.webp')}';

  static String storyBackgroundURL(String name) =>
      '$storyBackgroundPath/${_imageFilename(name)}';

  static String storyImageURL(String name) =>
      '$storyImagePath/${_imageFilename(name)}';

  static String _imageFilename(String name) => Uri.encodeComponent(
    RegExp(r'\.(png|webp|jpe?g)$', caseSensitive: false).hasMatch(name)
        ? name
        : '$name.png',
  );

  // Prefer the exact expression/pose; shorter default variants occur in arkdata.
  static List<String> storyCharacterURLs(String name) {
    final canonical = _storyCharacterKey(name);
    final match = RegExp(r'^(.*?)#(\d+)\$(\d+)$').firstMatch(canonical)!;
    final id = match.group(1)!;
    final face = match.group(2)!;
    final pose = match.group(3)!;
    final keys = [
      canonical,
      if (pose == '1') '$id#$face',
      if (face == '1') '$id\$$pose',
      if (face == '1' && pose == '1') id,
    ];
    return [
      for (final key in keys)
        for (final extension in ['png', 'webp'])
          '$storyCharacterPath/${Uri.encodeComponent('$key.$extension')}',
    ];
  }
}

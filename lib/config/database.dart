import 'config.dart';

class Database {
  // path to story review meta data, review info
  static const _defaultRoot =
      'https://raw.githubusercontent.com/KakkoiiSaber/arkstory_data/main/';
  static String get reviewManifestURL => const String.fromEnvironment(
    'STORY_REVIEW_MANIFEST_URL',
    defaultValue: '${_defaultRoot}data/media.json',
  );
  static String get reviewDataURL =>
      Uri.parse(reviewManifestURL).resolve('../').toString();
  static String get storyMetaTablePath =>
      '${reviewDataURL}data/${Config.server}/index.json';
  static String get gameMusicDataPath => '$storyMetaTablePath#homeMusic';
  static String get reviewInfoPath =>
      '${reviewDataURL}data/${Config.server}/stories/';
  static final detailPaths = <String, String>{};
  static String detailURL(String id) =>
      detailPaths['$storyMetaTablePath:$id'] ?? '$reviewInfoPath$id.json';
  static String get kvImagePath => reviewDataURL;
  static String get titleImagePath => reviewDataURL;
  static String get backgroundPath => reviewDataURL;
  static String get gameMusicPath => reviewDataURL;
  static String reviewAssetURL(String base, String value) =>
      Uri.parse(base).resolve(value).toString();

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
  static const storyAssetsURL = "https://torappu.prts.wiki";
  static String storyBackgroundPath = "$storyAssetsURL/assets/avg/background";
  static String storyImagePath = "$storyAssetsURL/assets/avg/images";
  static String storyMusicPath = "$storyAssetsURL/assets/audio/";
  static String storySoundPath = "$storyAssetsURL/assets/audio/";
  static String storyCharacterPath = "$storyAssetsURL/assets/avg/characters";
  static const characterIndexURL = '$storyAssetsURL/assets/avg/character.json';

  static String portraitURL(String key) =>
      '$storyCharacterPath/${key.split('/').map(Uri.encodeComponent).join('/')}.png';

  static Map? portrait(String name, Map catalog) {
    final match = RegExp(
      r'^([^#$]+)(?:#(\d+))?(?:\$(\d+))?$',
    ).firstMatch(name.trim().toLowerCase());
    if (match == null) return null;
    final node = catalog[match[1]];
    final entries = node?['array'];
    if (entries is! List || entries.isEmpty) return null;
    final index = int.parse(match[2] ?? '1') - 1;
    final body = int.parse(match[3] ?? '1') - 1;
    final entry = entries.cast<Map>().firstWhere(
      (e) => e['body'] == body && e['index'] == index,
      orElse: () => entries.first as Map,
    );
    if (entry['image'] is String) return {'image': portraitURL(entry['image'])};
    final groupIndex = entry['group'];
    final groups = node['groups'];
    if (groups is! List ||
        groupIndex is! int ||
        groupIndex < 0 ||
        groupIndex >= groups.length)
      return null;
    final group = groups[groupIndex];
    if (group['base'] is! String ||
        entry['face'] is! String ||
        group['faceRect'] is! Map)
      return null;
    return {
      'image': portraitURL(group['base']),
      'face': portraitURL(entry['face']),
      'rect': group['faceRect'],
      'size': node['size'],
    };
  }

  static String storyBackgroundURL(String name) =>
      '$storyBackgroundPath/${_imageFilename(name)}';

  static String storyImageURL(String name) =>
      '$storyImagePath/${_imageFilename(name)}';

  static String _imageFilename(String name) => Uri.encodeComponent(
    RegExp(r'\.(png|webp|jpe?g)$', caseSensitive: false).hasMatch(name)
        ? name
        : '$name.png',
  );
}

import 'config.dart';

class Database {
  // to store processed meta data and assets for cover, title, bg
  static String dataSourceURL1 = "https://raw.githubusercontent.com/KakkoiiSaber/arknights_story_data/main";
  static const assetsSourceURL1 = "https://raw.githubusercontent.com/KakkoiiSaber/arkdata/main";
  // static const assetsSourceURL1 = "https://raw.githubusercontent.com/KakkoiiSaber/arkdata/dev_bg_music";
  static const assetsSourceURL2 = "https://raw.githubusercontent.com/KakkoiiSaber/arkdata/main";

  // to store story data and assets
  static String dataSourceURL2 = "https://raw.githubusercontent.com/ArknightsAssets/ArknightsGamedata/main";
  // static const assetsSourceURL2 = "https://raw.githubusercontent.com/akgcc/arkdata/main";

  static String storyMetaTablePath = "$dataSourceURL1/assets/${Config.server}/story_meta_table.json";
  static String gameMusicTablePath = "$dataSourceURL1/assets/${Config.server}/audio_table.json";

  static const kvImagePath = "$assetsSourceURL1/assets/torappu/dynamicassets/arts/ui/mixstory/kvs/";
  static const titleImagePath = "$assetsSourceURL1/assets/torappu/dynamicassets/arts/ui/mixstory/titles/";
  static const backgroundPath = "$assetsSourceURL1/assets/torappu/dynamicassets/arts/ui/mixstory/retrobkgs/";

  static const musicPath = "$assetsSourceURL2/assets/torappu/dynamicassets/";
}

import 'config.dart';

class Database {
  static String dataSourceURL = "https://raw.githubusercontent.com/KakkoiiSaber/arknights_story_data/main";
  static const assetsSourceURL = "https://raw.githubusercontent.com/KakkoiiSaber/arkdata/main";

  static String storyMetaTablePath = "assets/${Config.server}/story_meta_table.json";
  static const kvImagePath = "assets/torappu/dynamicassets/arts/ui/mixstory/kvs";
  static const titleImagePath = "assets/torappu/dynamicassets/arts/ui/mixstory/titles";
  static const backgroundPath = "assets/torappu/dynamicassets/arts/ui/mixstory/retrobkgs";
}

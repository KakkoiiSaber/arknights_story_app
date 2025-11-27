import 'config.dart';

class Database {
  // path to story review meta data, review info
  static String reviewDataURL = "https://raw.githubusercontent.com/KakkoiiSaber/arknights_story_data/main";
  
  static String storyMetaTablePath = "$reviewDataURL/assets/${Config.server}/story_meta_table.json";
  static String gameMusicDataPath = "$reviewDataURL/assets/${Config.server}/audio_data.json";
  static String reviewInfoPath = "$reviewDataURL/assets/${Config.server}/story_review_info/";

  // path to story review assets
  static const reviewAssetsURL = "https://raw.githubusercontent.com/KakkoiiSaber/arkdata/main";
  //story cover images
  static const kvImagePath = "$reviewAssetsURL/assets/torappu/dynamicassets/arts/ui/mixstory/kvs/";
  // story title images
  static const titleImagePath = "$reviewAssetsURL/assets/torappu/dynamicassets/arts/ui/mixstory/titles/";
  // story review background images
  static const backgroundPath = "$reviewAssetsURL/assets/torappu/dynamicassets/arts/ui/mixstory/retrobkgs/";
  // story review music assets
  static const gameMusicPath = "$reviewAssetsURL/assets/torappu/dynamicassets/";

  // path to story data
  static String storyDataURLCN = "https://raw.githubusercontent.com/Kengxxiao/ArknightsGameData/master";
  static String storyDataURLGlobal = "https://raw.githubusercontent.com/Kengxxiao/ArknightsGameData_YoStar/main";
  static String storyContentPath = Config.server == "zh_CN" ? "$storyDataURLCN/${Config.server}/gamedata/story/" : "$storyDataURLGlobal/${Config.server}/gamedata/excel/story/";


}

import 'config.dart';

class DataBase {
  static String dataSourceURL = "https://raw.githubusercontent.com/ArknightsAssets/ArknightsGamedata/master/${Config.server}/gamedata";
  static const assetsSourceURL = "https://raw.githubusercontent.com/akgcc/arkdata/main/assets/";

  // audioMapURL: https://raw.githubusercontent.com/ArknightsAssets/ArknightsGamedata/master/cn/gamedata/excel/audio_data.json
  static String audioMapURL = "${dataSourceURL}/excel/audio_data.json";
  // storyMapURL: https://raw.githubusercontent.com/ArknightsAssets/ArknightsGamedata/master/cn/gamedata/excel/story_review_table.json
  static String storyMapURL = "${dataSourceURL}/excel/story_review_table.json";
  static String storyDataURL = "${dataSourceURL}/story";
}

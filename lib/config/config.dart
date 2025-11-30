class Config {
  static bool isSoundEnabled = true;
  static List<String> serverList = ["zh_CN", "en_US", "ja_JP", "ko_KR"];
  static String server = "zh_CN";
  static double layoutSwitchSize = 1080;


  static void setServer(String server){
    Config.server = server;
  }

  static void toggleSoundEnabled() {
    isSoundEnabled = !isSoundEnabled;
  }
}

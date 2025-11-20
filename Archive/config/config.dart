class Config {
  static bool isSoundEnabled = true;
  static List<String> serverList = ["en", "jp", "kr", "cn"];
  static String server = "cn";


  static void setServer(String server){
    Config.server = server;
  }

  static void toggleSoundEnabled() {
    isSoundEnabled = !isSoundEnabled;
  }
}

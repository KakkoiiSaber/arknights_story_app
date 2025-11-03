import 'package:flutter/material.dart';
import '../utils/audio_manager.dart';
import '../utils/data_retriever.dart';
import '../components/home_page/story_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final audio = AudioManager();

  void _toggleMute() {
    setState(() {
      audio.toggleMute();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Arknights Story App"),
        backgroundColor: Colors.grey[900],
        actions: [
          IconButton(
            icon: Icon(audio.isMuted ? Icons.volume_off : Icons.volume_up),
            onPressed: _toggleMute,
          ),
        ],
      ),
      body: FutureBuilder(
        future: DataRetriever.getStoryMap(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: TextStyle(color: Colors.red)));
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("No data", style: TextStyle(color: Colors.white)));
          }

          final storyMap = snapshot.data as Map<String, dynamic>;
          final keys = storyMap.keys.toList();
          final filteredKeys = keys.where((k) => storyMap[k]["entryType"] != "NONE").toList();
          final names = filteredKeys.map((k) => storyMap[k]["name"] as String).toList();
          final coverURLs = filteredKeys.map((k) => storyMap[k]["coverURL"] as String? ?? "").toList();

          // test: got cover url from coverJson where "id" is key
          // final coverJson = "https://image-1258734717.cos.ap-beijing.myqcloud.com/ASSD/zh_CN/main.json";
      

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1, 
            ),
            itemCount: names.length,
            itemBuilder: (context, index) {
              return StoryCard(
                name: names[index],
                coverURL: coverURLs[index],
                onTap: () {
                  print("Clicked ${filteredKeys[index]}");
                  // later: Navigator push to chapter page...
                },
              );
            },
          );

        },
      ),
    );
  }
}

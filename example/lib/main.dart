import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:audio_manager/audio_manager.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';

  final list = [
    {
      "desc": "assets playback",
      "url": "assets/xv.mp3",
      "coverUrl": "assets/ic_launcher.png"
    },
    {
      "desc": "assets playback",
      "url": "assets/incoming.wav",
      "coverUrl": "assets/ic_launcher.png"
    },
    {
      "desc": "network resouce playback",
      "url": "https://dl.espressif.com/dl/audio/ff-16b-2c-44100hz.m4a",
      "coverUrl": "https://homepages.cae.wisc.edu/~ece533/images/airplane.png"
    }
  ];

  @override
  void initState() {
    super.initState();

    initPlatformState();
    setupAudio();
    loadFile();
  }

  @override
  void dispose() {
    AudioManager.instance.release();
    super.dispose();
  }

  void setupAudio()
  {
    List<AudioInfo> _list = [];
    list.forEach((item) => _list.add(AudioInfo(item["url"])));

    AudioManager.instance.audioList = _list;
    AudioManager.instance.play(auto: false);

    AudioManager.instance.onEvents((events, args) {
      print("$events, $args");
      switch (events) {
        case AudioManagerEvents.start:
          print("start load data callback, curIndex is ${AudioManager.instance.curIndex}");
          break;
        case AudioManagerEvents.ready:
          print("ready to play");
          // if you need to seek times, must after AudioManagerEvents.ready event invoked
          // AudioManager.instance.seekTo(Duration(seconds: 10));
          break;
        case AudioManagerEvents.error:
          break;
        case AudioManagerEvents.ended:
          break;
        default:
          break;
      }
    });
  }

  void loadFile() async {
    // read bundle file to local path
    final audioFile = await rootBundle.load("assets/aLIEz.m4a");
    final audio = audioFile.buffer.asUint8List();

    final appDocDir = await getApplicationDocumentsDirectory();
    print(appDocDir);

    final file = File("${appDocDir.path}/aLIEz.m4a");
    file.writeAsBytesSync(audio);

    AudioInfo info = AudioInfo("file://${file.path}");

    list.add(info.toJson());
    AudioManager.instance.audioList.add(info);
    setState(() {});
  }

  Future<void> initPlatformState() async {
    String platformVersion;
    try {
      platformVersion = await AudioManager.instance.platformVersion;
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin audio player'),
        ),
        body: Center(
          child: Column(
            children: <Widget>[
              Text('Running on: $_platformVersion\n'),
              Expanded(
                child: ListView.separated(
                    itemBuilder: (context, index)
                    {
                      return ListTile(
                        title: Text(list[index]["url"],
                            style: TextStyle(fontSize: 18)),
                        onTap: () => AudioManager.instance.play(index: index),
                      );
                    },
                    separatorBuilder: (BuildContext context, int index) =>
                        Divider(),
                    itemCount: list.length),
              ),
              bottomPanel()
            ],
          ),
        ),
      ),
    );
  }

  Widget bottomPanel()
  {
    return Column(children: <Widget>[
      Container(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            IconButton(
                icon: Icon(
                  Icons.stop,
                  color: Colors.black,
                ),
                onPressed: () => AudioManager.instance.stop()),
          ],
        ),
      ),
    ]);
  }
}

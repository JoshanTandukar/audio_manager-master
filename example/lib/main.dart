import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:audio_manager/audio_manager.dart';

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
  ];

  @override
  void initState() {
    super.initState();

    initPlatformState();
    setupAudio();
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

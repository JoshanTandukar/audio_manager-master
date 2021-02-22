import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:audio_manager/src/AudioType.dart';
import 'package:audio_manager/src/AudioInfo.dart';

export 'package:audio_manager/src/AudioInfo.dart';
export 'package:audio_manager/src/AudioType.dart';

class AudioManager {
  static AudioManager _instance;
  static AudioManager get instance => _getInstance();

  static _getInstance()
  {
    if (_instance == null)
    {
      _instance = new AudioManager._();
    }
    return _instance;
  }

  static MethodChannel _channel;

  AudioManager._()
  {
    _channel = const MethodChannel('audio_manager')..setMethodCallHandler(_handler);
  }

  /// If there are errors, return details
  String get error => _error;
  String _error;

  /// list of playback. Used to record playlists
  List<AudioInfo> get audioList => _audioList;
  List<AudioInfo> _audioList = [];

  /// Set up playlists. Use the [play] or [start] method if you want to play
  set audioList(List<AudioInfo> list)
  {
    if (list == null || list.length == 0)
      throw "[list] can not be null or empty";
    _audioList = list;
    _info = _audioList[0];
  }

  /// Whether to auto play. default true
  bool get auto => _auto;
  bool _auto = true;

  /// Playback info
  AudioInfo get info => _info;
  AudioInfo _info;

  Future<dynamic> _handler(MethodCall call) {
    switch (call.method)
    {
      case "ready":
        _onEvents(AudioManagerEvents.ready, null);
        break;
      case "error":
        _error = call.arguments;
        _onEvents(AudioManagerEvents.error, _error);
        break;
      case "ended":
        play();
        _onEvents(AudioManagerEvents.ended, null);
        break;
      case "stop":
        _onEvents(AudioManagerEvents.stop, null);
        break;
      default:
        _onEvents(AudioManagerEvents.unknow, call.arguments);
        break;
    }
    return Future.value(true);
  }

  Events _events;

  void onEvents(Events events)
  {
    _events = events;
  }

  void _onEvents(AudioManagerEvents events, args)
  {
    if (_events == null) return;
    _events(events, args);
  }

  Future<String> get platformVersion async
  {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  Future<String> start(String url, {bool auto}) async
  {
    if (url == null || url.isEmpty) return "[url] can not be null or empty";
    _info = AudioInfo(url);
    _audioList.insert(0, _info);
    return await play();
  }

  /// This will load the file from the file-URI given by:
  /// `'file://${file.path}'`.
  Future<String> file(File file, {bool auto}) async
  {
    return await start("file://${file.path}", auto: auto);
  }

  Future<String> startInfo(AudioInfo audio, {bool auto}) async {
    return await start(audio.url,auto: auto);
  }

  Future<String> play() async {
    _onEvents(AudioManagerEvents.start, _audioList[0]);

    final result = await _channel.invokeMethod('start',
    {
      "url": _info.url,
    });
    return result;
  }

  stop()
  {
    _channel.invokeMethod("stop");
  }

  /// release all resource
  release()
  {
    _channel.invokeListMethod("release");
  }
}

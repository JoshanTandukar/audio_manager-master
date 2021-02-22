/// Play callback event enumeration
enum AudioManagerEvents {
  /// start load data
  start,

  /// ready to play. If you want to invoke [seekTo], you must follow this callback
  ready,
  error,
  ended,

  /// Android notification bar click Close
  stop,

  /// ⚠️ IOS simulator is invalid, please use real machine
  unknow
}
typedef void Events(AudioManagerEvents events, args);

class PlaybackState {
  final AudioState state;

  final Duration position;

  final Duration bufferedSize;

  final error;

  const PlaybackState(
    this.state, {
    this.position,
    this.bufferedSize,
    this.error,
  }) : assert(state != null);

  const PlaybackState.none()
      : this(
          AudioState.none,
          position: const Duration(seconds: 0),
          bufferedSize: const Duration(seconds: 0),
        );
}

/// play state
enum AudioState { none, paused, playing, error }

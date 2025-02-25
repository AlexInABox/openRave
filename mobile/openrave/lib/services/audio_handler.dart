import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:audio_session/audio_session.dart';
import 'backend_handler.dart';
import 'service_locator.dart'; // Import the setupLocator function
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as yt_iframe;

class RaveAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler, ChangeNotifier {
  final YoutubeExplode _yt = YoutubeExplode();
  final RoomController _roomController = RoomController();

  //iFrame integration.. uhhggg..
  final controller = yt_iframe.YoutubePlayerController(
    params: const yt_iframe.YoutubePlayerParams(
      showFullscreenButton: false,
      showControls: false,
      enableCaption: false,
      enableJavaScript: false,
      enableKeyboard: false,
      playsInline: false,
      showVideoAnnotations: false,
      pointerEvents: yt_iframe.PointerEvents.none,
    ),
  );

  Duration getPosition() => SimulatedAudioHandler().position;
  MediaItem? currentMediaItem;

  bool _isFirstRun = true;
  Future<void> init() async {
    if (_isFirstRun) {
      final AudioSession session = getIt.get<AudioSession>();
      session.interruptionEventStream.listen((event) {
        var simulatedAudioHandler = SimulatedAudioHandler();

        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              // Another app started playing audio and we should duck.
              break;
            case AudioInterruptionType.pause:
              if (simulatedAudioHandler.isPlaying) controller.playVideo();
              // Another app started playing audio and we should pause.
              break;
            case AudioInterruptionType.unknown:
              // Another app started playing audio and we should pause.
              if (simulatedAudioHandler.isPlaying) controller.playVideo();
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              // The interruption ended and we should unduck.
              break;
            case AudioInterruptionType.pause:
              // The interruption ended and we should resume.
              break;
            case AudioInterruptionType.unknown:
              // The interruption ended but we should not resume.
              break;
          }
        }
      });
      _isFirstRun = false;
    }
  }

  Future<void> catchUp(String videoId, Duration time, String state) async {
    SimulatedAudioHandler().reset();
    SimulatedAudioHandler().seek(time);
    if (state == "playing") {
      SimulatedAudioHandler().play();
    } else {
      SimulatedAudioHandler().pause();
    }

    _notifyAudioHandlerAboutPlaybackEvents();

    await refreshMetadata(videoId);
    await controller.loadVideoById(videoId: videoId);

    await syncControllerWithPrediction();
  }

  Future<void> loadNoPlay(String videoId) async {
    SimulatedAudioHandler().reset();
    SimulatedAudioHandler().pause();
    await controller.pauseVideo();

    await refreshMetadata(videoId);
    await controller.loadVideoById(videoId: videoId);

    await syncControllerWithPrediction();
  }

  late Video video;
  Future<void> refreshMetadata(String videoId) async {
    video = await _yt.videos.get("https://music.youtube.com/watch?v=$videoId");
    currentMediaItem = MediaItem(
      id: videoId,
      album: "YouTube Music",
      title: video.title,
      artist: video.author,
      duration: video.duration,
      artUri: Uri.parse(
          "https://yttf.zeitvertreib.vip/?url=https://music.youtube.com/watch?v=$videoId"),
    );
    mediaItem.add(currentMediaItem!);
    notifyListeners();
  }

  @override
  Future<void> play() async {
    final yt_iframe.PlayerState _playerState = await controller.playerState;

    if (_playerState == yt_iframe.PlayerState.ended) {
      seek(Duration.zero);
    }
    SimulatedAudioHandler().play();

    _roomController.play();
    controller.playVideo();

    playbackState.add(playbackState.value.copyWith(
      playing: true,
    ));
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    var simulatedAudioHandler = SimulatedAudioHandler();
    simulatedAudioHandler.pause();

    _roomController.pause();
    controller.pauseVideo();

    playbackState.add(playbackState.value.copyWith(
      playing: SimulatedAudioHandler().isPlaying,
    ));
    notifyListeners();
  }

  Future<void> playNoNotify() async {
    var simulatedAudioHandler = SimulatedAudioHandler();
    simulatedAudioHandler.play();

    controller.playVideo();

    playbackState.add(playbackState.value.copyWith(
      playing: true,
    ));
    notifyListeners();
  }

  Future<void> pauseNoNotify() async {
    var simulatedAudioHandler = SimulatedAudioHandler();
    simulatedAudioHandler.pause();

    controller.pauseVideo();
    playbackState.add(playbackState.value.copyWith(
      playing: SimulatedAudioHandler().isPlaying,
    ));
    notifyListeners();
  }

  @override
  Future<void> seek(Duration position) async {
    SimulatedAudioHandler().seek(position);

    _roomController.seek(position.inSeconds.toDouble());
    controller.seekTo(
        seconds: position.inSeconds.toDouble(), allowSeekAhead: true);

    playbackState.add(playbackState.value.copyWith(
      updatePosition: SimulatedAudioHandler().position,
    ));
    notifyListeners();
  }

  Future<void> seekNoNotify(Duration position) async {
    var simulatedAudioHandler = SimulatedAudioHandler();
    simulatedAudioHandler.seek(position);

    controller.seekTo(
        seconds: position.inSeconds.toDouble(), allowSeekAhead: true);

    playbackState.add(playbackState.value.copyWith(
      updatePosition: SimulatedAudioHandler().position,
    ));
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    var simulatedAudioHandler = SimulatedAudioHandler();
    simulatedAudioHandler.reset();

    await controller.stopVideo();
    _yt.close();

    playbackState.add(playbackState.value.copyWith(
      playing: SimulatedAudioHandler().isPlaying,
      processingState: AudioProcessingState.idle,
    ));
    notifyListeners();
  }

  @override
  Future<void> skipToPrevious() async {
    SimulatedAudioHandler().seek(Duration.zero);

    //always restart the song instead of going back one song. I dont want that now!
    _roomController.seek(0);
    await controller.seekTo(seconds: 0, allowSeekAhead: true);

    playbackState.add(playbackState.value.copyWith(
      playing: SimulatedAudioHandler().isPlaying,
      updatePosition: SimulatedAudioHandler().position,
    ));
    notifyListeners();
  }

  @override
  Future<void> skipToNext() async {
    final double videoLength = await controller.duration;
    //TODO: Duration might not exist when the audio is still loading
    SimulatedAudioHandler().pause();
    SimulatedAudioHandler().seek(Duration(seconds: videoLength.toInt()));

    _roomController.seek(videoLength);
    _roomController.pause();

    controller.seekTo(seconds: videoLength, allowSeekAhead: true);
    controller.pauseVideo();

    playbackState.add(playbackState.value.copyWith(
      playing: SimulatedAudioHandler().isPlaying,
      updatePosition: SimulatedAudioHandler().position,
    ));
    notifyListeners();
  }

  bool get isPlaying => SimulatedAudioHandler().isPlaying;

  void _notifyAudioHandlerAboutPlaybackEvents() {
    controller.videoStateStream.listen((event) async {
      final yt_iframe.PlayerState playState = await controller.playerState;
      final playing = playState == yt_iframe.PlayerState.playing;
      final bufferedPosition = Duration(
        milliseconds:
            (controller.metadata.duration.inMilliseconds * event.loadedFraction)
                .round(),
      );

      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.skipToPrevious,
          MediaAction.seek,
          MediaAction.play,
          MediaAction.pause,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: AudioProcessingState.ready,
        playing: playing,
        updatePosition: event.position,
        bufferedPosition: bufferedPosition,
        speed: 1.0,
        queueIndex: 0,
      ));
      notifyListeners();
    });

    controller.listen((event) async {
      final yt_iframe.PlayerState playState = await controller.playerState;
      final playing = playState == yt_iframe.PlayerState.playing;

      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.skipToPrevious,
          MediaAction.seek,
          MediaAction.play,
          MediaAction.pause,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: const {
          yt_iframe.PlayerState.buffering: AudioProcessingState.buffering,
          yt_iframe.PlayerState.cued: AudioProcessingState.ready,
          yt_iframe.PlayerState.playing: AudioProcessingState.ready,
          yt_iframe.PlayerState.ended: AudioProcessingState.ready,
          yt_iframe.PlayerState.paused: AudioProcessingState.ready,
          yt_iframe.PlayerState.unStarted: AudioProcessingState.loading,
        }[event.playerState]!,
        playing: playing,
        updatePosition: SimulatedAudioHandler().position,
      ));

      notifyListeners();
    });
  }

  Future<void> syncControllerWithPrediction() async {
    if (SimulatedAudioHandler().isPlaying) {
      await controller.playVideo();
    } else {
      await controller.pauseVideo();
    }

    await controller.seekTo(
        seconds: SimulatedAudioHandler().position.inSeconds.toDouble(),
        allowSeekAhead: true);
  }
}

class SimulatedAudioHandler {
  // Private constructor
  SimulatedAudioHandler._internal();

  // The single instance of the class
  static final SimulatedAudioHandler _instance =
      SimulatedAudioHandler._internal();

  // Factory constructor to return the same instance
  factory SimulatedAudioHandler() {
    return _instance;
  }

  final stopwatch = Stopwatch();
  Duration lastSeekPosition = Duration.zero;

  // Your methods and properties here
  void play() {
    stopwatch.start();
  }

  void pause() {
    stopwatch.stop();
  }

  void seek(Duration position) {
    lastSeekPosition = position;
    if (stopwatch.isRunning) {
      stopwatch.reset();
      stopwatch.start();
    }
    stopwatch.reset();
  }

  void reset() {
    stopwatch.stop();
    stopwatch.reset();
    lastSeekPosition = Duration.zero;
  }

  bool get isPlaying => stopwatch.isRunning;

  Duration get position {
    return stopwatch.elapsed + lastSeekPosition;
  }
}

import 'dart:io';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:audio_session/audio_session.dart';
import 'backend_handler.dart';
import 'service_locator.dart'; // Import the setupLocator function
import 'package:youtube_player_iframe/youtube_player_iframe.dart'
    as youtube_player_iframe;

class RaveAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler, ChangeNotifier {
  final YoutubeExplode _yt = YoutubeExplode();
  final RoomController _roomController = RoomController();

  //iFrame integration.. uhhggg..
  final controller = youtube_player_iframe.YoutubePlayerController(
    params: const youtube_player_iframe.YoutubePlayerParams(
      showFullscreenButton: false,
      showControls: false,
      enableCaption: false,
      enableJavaScript: false,
      enableKeyboard: false,
      playsInline: true,
      showVideoAnnotations: false,
    ),
  );

  late Video video;
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
    var simulatedAudioHandler = SimulatedAudioHandler();

    simulatedAudioHandler.reset();
    simulatedAudioHandler.seek(time);
    if (state == "playing") {
      simulatedAudioHandler.play();
    } else {
      simulatedAudioHandler.pause();
    }

    _notifyAudioHandlerAboutPlaybackEvents();
    _listenToPositionChanges();

    await refreshMetadata(videoId);
    await controller.loadVideoById(videoId: videoId);

    //For the video to properly display we need to play and pause it first
    await controller.playVideo();
    await controller.pauseVideo();

    //The wait is over lets sync
    await seekNoNotify(simulatedAudioHandler.position);
    if (simulatedAudioHandler.isPlaying) {
      playNoNotify();
    } else {
      pauseNoNotify();
    }
  }

  Future<void> loadNoPlay(String videoId) async {
    var simulatedAudioHandler = SimulatedAudioHandler();

    simulatedAudioHandler.reset();
    simulatedAudioHandler.pause();

    try {
      pauseNoNotify();
      await refreshMetadata(videoId);
      await controller.loadVideoById(videoId: videoId);
      await controller.playVideo();
      await controller.pauseVideo();

      //The wait is over lets sync
      await seekNoNotify(simulatedAudioHandler.position);
      if (simulatedAudioHandler.isPlaying) {
        playNoNotify();
      } else {
        pauseNoNotify();
      }
    } catch (e) {
      print("Error loading video: $e");
    }
  }

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
    var simulatedAudioHandler = SimulatedAudioHandler();
    simulatedAudioHandler.play();

    _roomController.play();
    controller.playVideo();

    notifyListeners();
  }

  @override
  Future<void> pause() async {
    var simulatedAudioHandler = SimulatedAudioHandler();
    simulatedAudioHandler.pause();

    _roomController.pause();
    controller.pauseVideo();

    notifyListeners();
  }

  Future<void> playNoNotify() async {
    var simulatedAudioHandler = SimulatedAudioHandler();
    simulatedAudioHandler.play();

    controller.playVideo();

    notifyListeners();
  }

  Future<void> pauseNoNotify() async {
    var simulatedAudioHandler = SimulatedAudioHandler();
    simulatedAudioHandler.pause();

    controller.pauseVideo();

    notifyListeners();
  }

  @override
  Future<void> seek(Duration position) async {
    SimulatedAudioHandler().seek(position);

    _roomController.seek(position.inSeconds.toDouble());
    controller.seekTo(
        seconds: position.inSeconds.toDouble(), allowSeekAhead: true);

    notifyListeners();
  }

  Future<void> seekNoNotify(Duration position) async {
    var simulatedAudioHandler = SimulatedAudioHandler();
    simulatedAudioHandler.seek(position);

    controller.seekTo(
        seconds: position.inSeconds.toDouble(), allowSeekAhead: true);

    notifyListeners();
  }

  @override
  Future<void> stop() async {
    var simulatedAudioHandler = SimulatedAudioHandler();
    simulatedAudioHandler.reset();

    await controller.stopVideo();
    _yt.close();
    playbackState.add(playbackState.value.copyWith(
      playing: false,
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

    notifyListeners();
  }

  bool get isPlaying => SimulatedAudioHandler().isPlaying;

  void _notifyAudioHandlerAboutPlaybackEvents() {
    controller.videoStateStream.listen((event) async {
      final youtube_player_iframe.PlayerState playState =
          await controller.playerState;
      final playing = playState == youtube_player_iframe.PlayerState.playing;

      if (playing != SimulatedAudioHandler().isPlaying) {
        if (playing) {
          SimulatedAudioHandler().play();
          _roomController.play();
        } else {
          SimulatedAudioHandler().pause();
          _roomController.pause();
        }
      }
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
        playing: playing,
        updatePosition: event.position,
        bufferedPosition: bufferedPosition,
        speed: 1.0,
        queueIndex: 0,
      ));

      notifyListeners();
    });
  }

  void _listenToPositionChanges() {
    controller.videoStateStream.listen((event) async {
      notifyListeners();
    });

    controller.listen((event) async {
      final youtube_player_iframe.PlayerState playState =
          await controller.playerState;
      final playing = playState == youtube_player_iframe.PlayerState.playing;

      if (playing != SimulatedAudioHandler().isPlaying) {
        if (playing) {
          SimulatedAudioHandler().play();
          _roomController.play();
        } else {
          SimulatedAudioHandler().pause();
          _roomController.pause();
        }
      }
      notifyListeners();
    });
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

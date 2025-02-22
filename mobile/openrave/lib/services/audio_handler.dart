import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:audio_session/audio_session.dart';
import 'backend_handler.dart';
import 'service_locator.dart'; // Import the setupLocator function

class RaveAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler, ChangeNotifier {
  late AudioPlayer _audioPlayer;
  late YoutubeExplode _yt;
  final RoomController _roomController = RoomController();
  bool _isFirstRun = true;

  late Video video;
  Duration position = Duration.zero;
  MediaItem? currentMediaItem;

  Future<void> init() async {
    _yt = YoutubeExplode();
    _audioPlayer = AudioPlayer(
      handleInterruptions: true,
      audioLoadConfiguration: AudioLoadConfiguration(
        darwinLoadControl: DarwinLoadControl(
          preferredForwardBufferDuration: Duration(seconds: 300),
        ),
      ),
    );

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
              if (simulatedAudioHandler.isPlaying) _audioPlayer.play();
              // Another app started playing audio and we should pause.
              break;
            case AudioInterruptionType.unknown:
              // Another app started playing audio and we should pause.
              if (simulatedAudioHandler.isPlaying) _audioPlayer.play();
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

  Future<String> getLink(String id) async {
    var manifest = await _yt.videos.streamsClient.getManifest(id, ytClients: [
      YoutubeApiClient.androidVr,
      YoutubeApiClient.android,
      YoutubeApiClient.ios,
      YoutubeApiClient.safari
    ]);
    return Platform.isIOS
        ? manifest.muxed.withHighestBitrate().url.toString()
        : manifest.audioOnly.withHighestBitrate().url.toString();
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

    _audioPlayer.positionStream.listen((event) {
      position = event;
      notifyListeners();
    });
    _notifyAudioHandlerAboutPlaybackEvents();
    _listenToCurrentPosition();

    await refreshMetadata(videoId);
    var link = await getLink(videoId);
    await _audioPlayer.setUrl(link);

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
      var link = await getLink(videoId);
      await _audioPlayer.setUrl(link);

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
    _audioPlayer.play();
  }

  @override
  Future<void> pause() async {
    var simulatedAudioHandler = SimulatedAudioHandler();
    simulatedAudioHandler.pause();

    _roomController.pause();
    _audioPlayer.pause();
  }

  Future<void> playNoNotify() async {
    var simulatedAudioHandler = SimulatedAudioHandler();
    simulatedAudioHandler.play();

    _audioPlayer.play();
  }

  Future<void> pauseNoNotify() async {
    var simulatedAudioHandler = SimulatedAudioHandler();
    simulatedAudioHandler.pause();

    _audioPlayer.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    var simulatedAudioHandler = SimulatedAudioHandler();
    simulatedAudioHandler.seek(position);

    _roomController.seek(position.inSeconds.toDouble());
    _audioPlayer.seek(position);
  }

  Future<void> seekNoNotify(Duration position) async {
    var simulatedAudioHandler = SimulatedAudioHandler();
    simulatedAudioHandler.seek(position);

    _audioPlayer.seek(position);
  }

  @override
  Future<void> stop() async {
    var simulatedAudioHandler = SimulatedAudioHandler();
    simulatedAudioHandler.reset();

    await _audioPlayer.stop();
    _audioPlayer.dispose();
    _yt.close();
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle,
    ));
  }

  @override
  Future<void> skipToPrevious() async {
    //always restart the song instead of going back one song. I dont want that now!
    _roomController.seek(0);
    await _audioPlayer.seek(Duration.zero);
  }

  @override
  Future<void> skipToNext() async {
    //TODO: Duration might not exist when the audio is still loading
    var simulatedAudioHandler = SimulatedAudioHandler();
    simulatedAudioHandler.seek(_audioPlayer.duration!);

    _roomController.seek(_audioPlayer.duration!.inSeconds.toDouble());
    _audioPlayer.seek(_audioPlayer.duration!);
    _audioPlayer.pause();
  }

  bool get isPlaying => _audioPlayer.playing;

  void _notifyAudioHandlerAboutPlaybackEvents() {
    _audioPlayer.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _audioPlayer.playing;
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
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_audioPlayer.processingState]!,
        playing: playing,
        updatePosition: _audioPlayer.position,
        bufferedPosition: _audioPlayer.bufferedPosition,
        speed: _audioPlayer.speed,
        queueIndex: event.currentIndex,
      ));
    });
  }

  void _listenToCurrentPosition() {
    _audioPlayer.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(updatePosition: position));
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

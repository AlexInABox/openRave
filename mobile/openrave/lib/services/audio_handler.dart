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
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              // Another app started playing audio and we should duck.
              break;
            case AudioInterruptionType.pause:
              if (predictedPlayingState) _audioPlayer.play();
              // Another app started playing audio and we should pause.
              break;
            case AudioInterruptionType.unknown:
              // Another app started playing audio and we should pause.
              if (predictedPlayingState) _audioPlayer.play();
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
    _audioPlayer.positionStream.listen((event) {
      position = event;
      notifyListeners();
    });
    _notifyAudioHandlerAboutPlaybackEvents();
    _listenToCurrentPosition();

    await refreshMetadata(videoId);
    var link = await getLink(videoId);
    await _audioPlayer.setUrl(link);
    await _audioPlayer.seek(time); // Seek to the specific time first
    if (state == "playing") {
      _audioPlayer.play(); // Start playing after the seek
    } else {
      _audioPlayer.pause();
    }
  }

  Future<void> loadAndPlay(String videoId) async {
    try {
      await refreshMetadata(videoId);
      var link = await getLink(videoId);
      await _audioPlayer.setUrl(link);
      playNoNotify();
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
    _roomController.play();
    _audioPlayer.play();
    predictedPlayingState = true;
  }

  @override
  Future<void> pause() async {
    _roomController.pause();
    _audioPlayer.pause();
    predictedPlayingState = false;
  }

  Future<void> playNoNotify() async {
    _audioPlayer.play();
    predictedPlayingState = true;
  }

  Future<void> pauseNoNotify() async {
    _audioPlayer.pause();
    predictedPlayingState = false;
  }

  @override
  Future<void> seek(Duration position) async {
    _roomController.seek(position.inSeconds.toDouble());
    _audioPlayer.seek(position);
  }

  Future<void> seekNoNotify(Duration position) => _audioPlayer.seek(position);

  @override
  Future<void> stop() async {
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
    _roomController.seek(_audioPlayer.duration!.inSeconds.toDouble());
    _audioPlayer.seek(_audioPlayer.duration!);
    _audioPlayer.pause();
  }

  bool predictedPlayingState = false;
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

import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:openrave/services/audio_handler.dart';
import 'intro.dart';
import 'home.dart';
import 'package:is_first_run/is_first_run.dart';

import 'services/service_locator.dart'; // Import the setupLocator function

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final session = await AudioSession.instance;
  await session.configure(
    AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
    ),
  );
  await session.setActive(true);

  final RaveAudioHandler audioHandler = await AudioService.init(
    builder: () => RaveAudioHandler(),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.alexinabox.openrave.channel.audio',
      androidNotificationChannelName: 'Music playback',
    ),
  );

  setupLocator(audioHandler); // Register the instance globally

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(MyApp());
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  Brightness? _brightness;
  late Future<bool> _isFirstRunFuture;

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    _brightness = PlatformDispatcher.instance.platformBrightness;
    _isFirstRunFuture = IsFirstRun.isFirstRun();
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (mounted) {
      setState(() {
        _brightness = PlatformDispatcher.instance.platformBrightness;
      });
    }

    super.didChangePlatformBrightness();
  }

  //Removed light theme for now. Not really happy with how it changes the feel of the app.
  CupertinoThemeData get _lightTheme => CupertinoThemeData(
        brightness: Brightness.dark, /* light theme settings */
      );

  CupertinoThemeData get _darkTheme => CupertinoThemeData(
        brightness: Brightness.dark, /* dark theme settings */
      );

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      theme: _brightness == Brightness.dark ? _darkTheme : _lightTheme,
      home: FutureBuilder<bool>(
        future: _isFirstRunFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CupertinoActivityIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Error occurred'));
          } else {
            bool isFirstRun = snapshot.data ?? true;
            if (isFirstRun) {
              return const Intro();
            } else {
              return const Home();
            }
          }
        },
      ),
    );
  }
}

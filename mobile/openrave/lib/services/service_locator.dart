import 'package:audio_session/audio_session.dart';
import 'package:get_it/get_it.dart';
import 'package:openrave/services/audio_handler.dart';

final GetIt getIt = GetIt.instance;

void setupLocator(RaveAudioHandler audioHandler) {
  getIt.registerSingleton<RaveAudioHandler>(audioHandler);
}

void setupAudioSession(AudioSession audioSession) {
  getIt.registerSingleton<AudioSession>(audioSession);
}

import 'package:get_it/get_it.dart';
import 'package:openrave/services/audio_handler.dart';

final GetIt getIt = GetIt.instance;

void setupLocator(RaveAudioHandler audioHandler) {
  getIt.registerSingleton<RaveAudioHandler>(audioHandler);
}

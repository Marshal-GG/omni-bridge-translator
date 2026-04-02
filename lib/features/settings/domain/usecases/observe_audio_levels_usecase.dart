import 'package:omni_bridge/features/settings/domain/repositories/i_audio_device_repository.dart';

class ObserveAudioLevelsUseCase {
  final IAudioDeviceRepository repository;

  ObserveAudioLevelsUseCase(this.repository);

  Stream<(double, double)> call() => repository.audioLevelStream;
}

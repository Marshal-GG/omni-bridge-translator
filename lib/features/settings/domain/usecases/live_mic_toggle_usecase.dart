import 'package:omni_bridge/features/settings/domain/repositories/i_audio_device_repository.dart';

class LiveMicToggleUseCase {
  final IAudioDeviceRepository _repository;

  LiveMicToggleUseCase(this._repository);

  void call(bool useMic) {
    _repository.liveMicToggle(useMic);
  }
}

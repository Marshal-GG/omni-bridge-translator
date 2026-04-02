import 'package:omni_bridge/features/settings/domain/repositories/i_audio_device_repository.dart';

class LiveDeviceUpdateUseCase {
  final IAudioDeviceRepository _repository;

  LiveDeviceUpdateUseCase(this._repository);

  void call({int? inputDeviceIndex, int? outputDeviceIndex}) {
    _repository.liveDeviceUpdate(
      inputDeviceIndex: inputDeviceIndex,
      outputDeviceIndex: outputDeviceIndex,
    );
  }
}

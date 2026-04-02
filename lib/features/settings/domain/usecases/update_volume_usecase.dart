import 'package:omni_bridge/features/settings/domain/repositories/i_audio_device_repository.dart';

class UpdateVolumeUseCase {
  final IAudioDeviceRepository _repository;

  UpdateVolumeUseCase(this._repository);

  void call({required double desktopVolume, required double micVolume}) {
    _repository.liveVolumeUpdate(
      desktopVolume: desktopVolume,
      micVolume: micVolume,
    );
  }
}

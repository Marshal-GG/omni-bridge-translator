import 'package:omni_bridge/features/settings/domain/repositories/i_audio_device_repository.dart';
import 'package:omni_bridge/features/translation/data/datasources/asr_websocket_datasource.dart';

class AudioDeviceRepositoryImpl implements IAudioDeviceRepository {
  final AsrWebSocketClient _asrClient;

  AudioDeviceRepositoryImpl(this._asrClient);

  @override
  Stream<(double, double)> get audioLevelStream => _asrClient.audioLevelStream;

  @override
  Future<Map<String, dynamic>> loadDevices() => _asrClient.loadDevices();

  @override
  void liveVolumeUpdate({
    required double desktopVolume,
    required double micVolume,
  }) =>
      _asrClient.liveVolumeUpdate(
        desktopVolume: desktopVolume,
        micVolume: micVolume,
      );

  @override
  void liveDeviceUpdate({int? inputDeviceIndex, int? outputDeviceIndex}) =>
      _asrClient.liveDeviceUpdate(
        inputDeviceIndex: inputDeviceIndex,
        outputDeviceIndex: outputDeviceIndex,
      );

  @override
  void liveMicToggle(bool useMic) => _asrClient.liveMicToggle(useMic);
}

import 'package:omni_bridge/features/settings/domain/entities/audio_device.dart';
import 'package:omni_bridge/features/settings/domain/repositories/i_audio_device_repository.dart';

class LoadDevicesUseCase {
  final IAudioDeviceRepository repository;

  LoadDevicesUseCase(this.repository);

  Future<DeviceListResult> call() async {
    final raw = await repository.loadDevices();

    final inputDevices = (raw['input'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map((d) => AudioDevice(name: d['name'] as String, index: d['index'] as int))
        .toList();

    final outputDevices = (raw['output'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map((d) => AudioDevice(name: d['name'] as String, index: d['index'] as int))
        .toList();

    return DeviceListResult(
      inputDevices: inputDevices,
      outputDevices: outputDevices,
      defaultInputName: raw['default_input_name'] as String? ?? 'Default',
      defaultOutputName: raw['default_output_name'] as String? ?? 'Default',
    );
  }
}

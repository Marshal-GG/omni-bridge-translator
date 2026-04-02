import 'package:equatable/equatable.dart';

class AudioDevice extends Equatable {
  final String name;
  final int index;

  const AudioDevice({required this.name, required this.index});

  @override
  List<Object?> get props => [name, index];
}

class DeviceListResult extends Equatable {
  final List<AudioDevice> inputDevices;
  final List<AudioDevice> outputDevices;
  final String defaultInputName;
  final String defaultOutputName;

  const DeviceListResult({
    required this.inputDevices,
    required this.outputDevices,
    required this.defaultInputName,
    required this.defaultOutputName,
  });

  factory DeviceListResult.empty() => const DeviceListResult(
    inputDevices: [],
    outputDevices: [],
    defaultInputName: 'Default',
    defaultOutputName: 'Default',
  );

  @override
  List<Object?> get props => [
    inputDevices,
    outputDevices,
    defaultInputName,
    defaultOutputName,
  ];
}

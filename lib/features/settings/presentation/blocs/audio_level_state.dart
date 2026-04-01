import 'package:equatable/equatable.dart';

class AudioLevelState extends Equatable {
  final double inputLevel;
  final double outputLevel;

  const AudioLevelState({this.inputLevel = 0.0, this.outputLevel = 0.0});

  @override
  List<Object?> get props => [inputLevel, outputLevel];

  AudioLevelState copyWith({double? inputLevel, double? outputLevel}) {
    return AudioLevelState(
      inputLevel: inputLevel ?? this.inputLevel,
      outputLevel: outputLevel ?? this.outputLevel,
    );
  }
}

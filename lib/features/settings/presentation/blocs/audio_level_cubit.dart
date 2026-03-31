import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/observe_audio_levels_usecase.dart';
import 'audio_level_state.dart';

class AudioLevelCubit extends Cubit<AudioLevelState> {
  final ObserveAudioLevelsUseCase observeAudioLevelsUseCase;

  AudioLevelCubit({
    required this.observeAudioLevelsUseCase,
  }) : super(const AudioLevelState()) {
    _init();
  }

  void _init() {
    observeAudioLevelsUseCase((inputLevel, outputLevel) {
      if (!isClosed) {
        emit(state.copyWith(
          inputLevel: inputLevel,
          outputLevel: outputLevel,
        ));
      }
    });
  }
}

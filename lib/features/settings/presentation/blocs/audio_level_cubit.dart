import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/observe_audio_levels_usecase.dart';
import 'audio_level_state.dart';

class AudioLevelCubit extends Cubit<AudioLevelState> {
  final ObserveAudioLevelsUseCase observeAudioLevelsUseCase;
  StreamSubscription<(double, double)>? _sub;

  AudioLevelCubit({required this.observeAudioLevelsUseCase})
    : super(const AudioLevelState()) {
    _sub = observeAudioLevelsUseCase().listen((levels) {
      if (!isClosed) {
        emit(state.copyWith(inputLevel: levels.$1, outputLevel: levels.$2));
      }
    });
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}

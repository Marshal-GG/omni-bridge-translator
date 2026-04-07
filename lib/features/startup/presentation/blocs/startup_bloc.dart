import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omni_bridge/core/platform/app_initializer.dart';
import 'package:omni_bridge/features/auth/domain/repositories/i_auth_repository.dart';
import 'startup_event.dart';
import 'startup_state.dart';

class StartupBloc extends Bloc<StartupEvent, StartupState> {
  // ignore: unused_field
  final IAuthRepository authRepository;

  StartupBloc({required this.authRepository}) : super(const StartupInitial()) {
    on<StartupInitializeEvent>(_onInitialize);
  }

  Future<void> _onInitialize(
    StartupInitializeEvent event,
    Emitter<StartupState> emit,
  ) async {
    emit(const StartupLoading());

    try {
      // Phase 2: auth validation + update check + server start (background).
      final route = await AppInitializer.initAsync();

      if (route == '/force_update') {
        emit(const StartupNavigateToForceUpdate());
      } else if (route == '/translation-overlay') {
        emit(const StartupNavigateToHome());
      } else {
        emit(const StartupNavigateToOnboarding());
      }
    } catch (e) {
      emit(StartupFailure(e.toString()));
    }
  }
}

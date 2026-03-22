import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omni_bridge/features/auth/domain/repositories/i_auth_repository.dart';
import 'startup_event.dart';
import 'startup_state.dart';

class StartupBloc extends Bloc<StartupEvent, StartupState> {
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
      // Simulate splash time or do any async initialization here
      await Future.delayed(const Duration(milliseconds: 2000));

      final isLoggedIn = authRepository.currentUser.value != null;

      if (isLoggedIn) {
        emit(const StartupNavigateToHome());
      } else {
        emit(const StartupNavigateToOnboarding());
      }
    } catch (e) {
      emit(StartupFailure(e.toString()));
    }
  }
}

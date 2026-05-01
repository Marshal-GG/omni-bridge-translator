import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omni_bridge/core/platform/app_initializer.dart';
import 'package:omni_bridge/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:omni_bridge/features/startup/domain/entities/update_info.dart';
import 'package:omni_bridge/features/startup/presentation/notifiers/update_notifier.dart';
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
      final (route, updateInfo) = await AppInitializer.initAsync(
        onProgress: (message, progress) {
          emit(StartupProgress(message, progress));
        },
      );

      // Presentation layer owns UpdateNotifier — datasource no longer pushes to it.
      if (updateInfo != null) {
        UpdateNotifier.instance.setAvailable(
          updateInfo.latestVersion ?? '',
          updateInfo.releaseUrl ?? '',
          download: updateInfo.downloadUrl,
          forced: updateInfo.status == UpdateInfoStatus.forced,
          message: updateInfo.forceUpdateMessage,
        );
      }

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

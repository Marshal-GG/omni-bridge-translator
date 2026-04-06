import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:omni_bridge/features/about/domain/usecases/check_for_update.dart';
import 'package:omni_bridge/features/about/domain/entities/update_result.dart';
import 'package:omni_bridge/features/startup/presentation/notifiers/update_notifier.dart';
import 'about_event.dart';
import 'about_state.dart';

class AboutBloc extends Bloc<AboutEvent, AboutState> {
  final CheckForUpdate _checkForUpdate;

  AboutBloc({required CheckForUpdate checkForUpdate})
    : _checkForUpdate = checkForUpdate,
      super(const AboutState()) {
    on<AboutInitEvent>(_onInit);
    on<AboutCheckUpdateEvent>(_onCheckUpdate);
  }

  Future<void> _onInit(AboutInitEvent event, Emitter<AboutState> emit) async {
    final info = await PackageInfo.fromPlatform();

    UpdateStatus status = UpdateStatus.idle;
    UpdateResult? result;

    if (UpdateNotifier.instance.value) {
      status = UpdateStatus.available;
      result = UpdateResult(
        status: status,
        latestVersion: UpdateNotifier.instance.latestVersion,
        releaseUrl: UpdateNotifier.instance.releaseUrl,
        downloadUrl: UpdateNotifier.instance.downloadUrl,
      );
    }

    emit(
      state.copyWith(
        version: info.version,
        updateStatus: status,
        updateResult: result,
      ),
    );
  }

  Future<void> _onCheckUpdate(
    AboutCheckUpdateEvent event,
    Emitter<AboutState> emit,
  ) async {
    emit(state.copyWith(updateStatus: UpdateStatus.checking));

    final result = await _checkForUpdate();

    if (result.status == UpdateStatus.available) {
      UpdateNotifier.instance.setAvailable(
        result.latestVersion!,
        result.releaseUrl!,
      );
    }

    emit(state.copyWith(updateStatus: result.status, updateResult: result));
  }
}

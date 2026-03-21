import 'package:omni_bridge/features/translation/domain/repositories/i_translation_repository.dart';

class LoadDevicesUseCase {
  final ITranslationRepository repository;

  LoadDevicesUseCase(this.repository);

  Future<Map<String, dynamic>> call() async {
    return await repository.loadDevices();
  }
}

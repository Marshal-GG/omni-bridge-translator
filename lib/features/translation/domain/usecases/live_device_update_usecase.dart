import '../repositories/i_translation_repository.dart';

class LiveDeviceUpdateUseCase {
  final ITranslationRepository _repository;

  LiveDeviceUpdateUseCase(this._repository);

  void call({int? inputDeviceIndex, int? outputDeviceIndex}) {
    _repository.liveDeviceUpdate(
      inputDeviceIndex: inputDeviceIndex,
      outputDeviceIndex: outputDeviceIndex,
    );
  }
}

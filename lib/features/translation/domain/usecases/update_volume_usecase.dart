import '../repositories/i_translation_repository.dart';

class UpdateVolumeUseCase {
  final ITranslationRepository _repository;

  UpdateVolumeUseCase(this._repository);

  void call({
    required double desktopVolume,
    required double micVolume,
  }) {
    _repository.liveVolumeUpdate(
      desktopVolume: desktopVolume,
      micVolume: micVolume,
    );
  }
}

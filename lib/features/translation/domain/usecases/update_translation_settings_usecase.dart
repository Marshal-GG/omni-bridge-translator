import 'package:omni_bridge/features/translation/domain/repositories/i_translation_repository.dart';

class UpdateTranslationSettingsUseCase {
  final ITranslationRepository repository;

  UpdateTranslationSettingsUseCase(this.repository);

  void call({
    required String sourceLang,
    required String targetLang,
    required bool useMic,
    int? inputDeviceIndex,
    int? outputDeviceIndex,
    double desktopVolume = 1.0,
    double micVolume = 1.0,
    required String translationModel,
    String apiKey = '',
    String googleCredentialsJson = '',
    String transcriptionModel = 'online',
  }) {
    repository.updateSettings(
      sourceLang: sourceLang,
      targetLang: targetLang,
      useMic: useMic,
      inputDeviceIndex: inputDeviceIndex,
      outputDeviceIndex: outputDeviceIndex,
      desktopVolume: desktopVolume,
      micVolume: micVolume,
      translationModel: translationModel,
      apiKey: apiKey,
      googleCredentialsJson: googleCredentialsJson,
      transcriptionModel: transcriptionModel,
    );
  }
}

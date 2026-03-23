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
    dynamic googleCredentials = '',
    String transcriptionModel = 'online',
    String rivaTranslationFunctionId = '',
    String rivaAsrParakeetFunctionId = '',
    String rivaAsrCanaryFunctionId = '',
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
      googleCredentials: googleCredentials,
      transcriptionModel: transcriptionModel,
      rivaTranslationFunctionId: rivaTranslationFunctionId,
      rivaAsrParakeetFunctionId: rivaAsrParakeetFunctionId,
      rivaAsrCanaryFunctionId: rivaAsrCanaryFunctionId,
    );
  }
}

import '../repositories/i_translation_repository.dart';

class StartTranslationUseCase {
  final ITranslationRepository _repository;

  StartTranslationUseCase(this._repository);

  void call({
    String sourceLang = 'auto',
    String targetLang = 'en',
    bool useMic = false,
    int? inputDeviceIndex,
    int? outputDeviceIndex,
    String translationModel = 'google',
    String apiKey = '',
    dynamic googleCredentials = '',
    String transcriptionModel = 'online',
    String rivaTranslationFunctionId = '',
    String rivaAsrParakeetFunctionId = '',
    String rivaAsrCanaryFunctionId = '',
  }) {
    _repository.start(
      sourceLang: sourceLang,
      targetLang: targetLang,
      useMic: useMic,
      inputDeviceIndex: inputDeviceIndex,
      outputDeviceIndex: outputDeviceIndex,
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

import 'package:omni_bridge/core/utils/app_logger.dart';
import '../../domain/entities/caption_message.dart';
import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';
import 'package:omni_bridge/features/subscription/data/datasources/subscription_remote_datasource.dart';
import '../datasources/asr_websocket_datasource.dart';
import '../datasources/translation_rest_datasource.dart';
import '../../domain/repositories/i_translation_repository.dart';

class TranslationRepositoryImpl implements ITranslationRepository {
  static const String _tag = 'TranslationRepo';
  final AsrWebSocketClient _asrClient;
  final TranslationRestDatasource _restDatasource;
  final SubscriptionRemoteDataSource _subscriptionService;

  TranslationRepositoryImpl(
    this._asrClient,
    this._restDatasource,
    this._subscriptionService,
  );

  @override
  Stream<CaptionMessage>? get captions => _asrClient.captions;

  @override
  QuotaStatus? get currentQuotaStatus => _subscriptionService.currentStatus;

  @override
  Stream<QuotaStatus> get quotaStatusStream =>
      _subscriptionService.statusStream;

  @override
  String get defaultTier => _subscriptionService.defaultTier;


  @override
  void start({
    String sourceLang = 'auto',
    String targetLang = 'en',
    bool useMic = false,
    int? inputDeviceIndex,
    int? outputDeviceIndex,
    String translationModel = 'google',
    String nvidiaNimKey = '',
    dynamic googleCredentials = '',
    String transcriptionModel = 'online',
    String rivaTranslationFunctionId = '',
    String rivaAsrParakeetFunctionId = '',
    String rivaAsrCanaryFunctionId = '',
    int quotaDailyUsed = 0,
    int quotaDailyLimit = -1,
  }) {
    _asrClient.start(
      sourceLang: sourceLang,
      targetLang: targetLang,
      useMic: useMic,
      inputDeviceIndex: inputDeviceIndex,
      outputDeviceIndex: outputDeviceIndex,
      translationModel: translationModel,
      nvidiaNimKey: nvidiaNimKey,
      googleCredentials: googleCredentials,
      transcriptionModel: transcriptionModel,
      rivaTranslationFunctionId: rivaTranslationFunctionId,
      rivaAsrParakeetFunctionId: rivaAsrParakeetFunctionId,
      rivaAsrCanaryFunctionId: rivaAsrCanaryFunctionId,
      quotaDailyUsed: quotaDailyUsed,
      quotaDailyLimit: quotaDailyLimit,
    );
  }

  @override
  void updateSettings({
    required String sourceLang,
    required String targetLang,
    required bool useMic,
    int? inputDeviceIndex,
    int? outputDeviceIndex,
    double desktopVolume = 1.0,
    double micVolume = 1.0,
    required String translationModel,
    String nvidiaNimKey = '',
    dynamic googleCredentials = '',
    String transcriptionModel = 'online',
    String rivaTranslationFunctionId = '',
    String rivaAsrParakeetFunctionId = '',
    String rivaAsrCanaryFunctionId = '',
  }) {
    _asrClient.updateSettings(
      sourceLang: sourceLang,
      targetLang: targetLang,
      useMic: useMic,
      inputDeviceIndex: inputDeviceIndex,
      outputDeviceIndex: outputDeviceIndex,
      desktopVolume: desktopVolume,
      micVolume: micVolume,
      translationModel: translationModel,
      nvidiaNimKey: nvidiaNimKey,
      googleCredentials: googleCredentials,
      transcriptionModel: transcriptionModel,
      rivaTranslationFunctionId: rivaTranslationFunctionId,
      rivaAsrParakeetFunctionId: rivaAsrParakeetFunctionId,
      rivaAsrCanaryFunctionId: rivaAsrCanaryFunctionId,
    );
  }


  @override
  Future<List<dynamic>> getModelStatuses() =>
      _restDatasource.getModelStatuses();

  @override
  Future<bool> checkServerHealth() => _restDatasource.checkHealth();

  @override
  Future<void> unloadModel() async {
    await _restDatasource.unloadModel();
  }

  @override
  Future<void> stop() async {
    // Unload the Whisper model from GPU/RAM on the server to free up resources.
    await _restDatasource.unloadModel();
    await _asrClient.stop();
  }

  @override
  void reset() {
    AppLogger.i('Resetting Translation Repository state...', tag: _tag);
    _asrClient.reset();
    _restDatasource.reset();
  }

  @override
  Future<void> dispose() => _asrClient.dispose();
}

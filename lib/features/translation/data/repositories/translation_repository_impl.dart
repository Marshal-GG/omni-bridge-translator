import '../../domain/entities/caption_message.dart';
import 'package:omni_bridge/features/subscription/data/models/subscription_dto.dart';
import 'package:omni_bridge/features/subscription/data/datasources/subscription_remote_datasource.dart';
import '../datasources/asr_websocket_datasource.dart';
import '../datasources/translation_rest_datasource.dart';
import '../../domain/repositories/i_translation_repository.dart';

class TranslationRepositoryImpl implements ITranslationRepository {
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
  SubscriptionStatus? get currentQuotaStatus =>
      _subscriptionService.currentStatus;

  @override
  Stream<SubscriptionStatus> get quotaStatusStream =>
      _subscriptionService.statusStream;

  @override
  String get defaultTier => _subscriptionService.defaultTier;

  @override
  set onAudioLevel(
    void Function(double inputLevel, double outputLevel)? callback,
  ) {
    _asrClient.onAudioLevel = callback;
  }

  @override
  void Function(double inputLevel, double outputLevel)? get onAudioLevel =>
      _asrClient.onAudioLevel;

  @override
  void start({
    String sourceLang = 'auto',
    String targetLang = 'en',
    bool useMic = false,
    int? inputDeviceIndex,
    int? outputDeviceIndex,
    String translationModel = 'google',
    String apiKey = '',
    String googleCredentialsJson = '',
    String transcriptionModel = 'online',
  }) {
    _asrClient.start(
      sourceLang: sourceLang,
      targetLang: targetLang,
      useMic: useMic,
      inputDeviceIndex: inputDeviceIndex,
      outputDeviceIndex: outputDeviceIndex,
      translationModel: translationModel,
      apiKey: apiKey,
      googleCredentialsJson: googleCredentialsJson,
      transcriptionModel: transcriptionModel,
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
    String apiKey = '',
    String googleCredentialsJson = '',
    String transcriptionModel = 'online',
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
      apiKey: apiKey,
      googleCredentialsJson: googleCredentialsJson,
      transcriptionModel: transcriptionModel,
    );
  }

  @override
  void liveVolumeUpdate({
    required double desktopVolume,
    required double micVolume,
  }) {
    _asrClient.liveVolumeUpdate(
      desktopVolume: desktopVolume,
      micVolume: micVolume,
    );
  }

  @override
  Future<Map<String, dynamic>> loadDevices() => _asrClient.loadDevices();

  @override
  Future<List<dynamic>> getModelStatuses() =>
      _restDatasource.getModelStatuses();

  @override
  void stop() => _asrClient.stop();

  @override
  Future<void> dispose() => _asrClient.dispose();
}

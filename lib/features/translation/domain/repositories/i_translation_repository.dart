import '../entities/caption_message.dart';
import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';

abstract class ITranslationRepository {
  Stream<CaptionMessage>? get captions;
  void Function(double inputLevel, double outputLevel)? onAudioLevel;

  // Quota support
  QuotaStatus? get currentQuotaStatus;
  Stream<QuotaStatus> get quotaStatusStream;
  String get defaultTier;

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
  });

  void updateSettings({
    required String sourceLang,
    required String targetLang,
    required bool useMic,
    int? inputDeviceIndex,
    int? outputDeviceIndex,
    double desktopVolume,
    double micVolume,
    required String translationModel,
    String nvidiaNimKey,
    dynamic googleCredentials,
    String transcriptionModel,
    String rivaTranslationFunctionId,
    String rivaAsrParakeetFunctionId,
    String rivaAsrCanaryFunctionId,
  });

  void liveVolumeUpdate({
    required double desktopVolume,
    required double micVolume,
  });

  Future<Map<String, dynamic>> loadDevices();
  Future<List<dynamic>> getModelStatuses();
  Future<bool> checkServerHealth();
  Future<void> stop();
  Future<void> dispose();
}

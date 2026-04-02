import '../entities/caption_message.dart';
import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';
import 'package:omni_bridge/core/data/interfaces/resettable.dart';


abstract class ITranslationRepository implements IResettable {
  Stream<CaptionMessage>? get captions;

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

  Future<List<dynamic>> getModelStatuses();
  Future<bool> checkServerHealth();
  Future<void> unloadModel();
  Future<void> stop();
  Future<void> dispose();
}

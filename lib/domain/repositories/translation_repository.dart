import 'package:omni_bridge/data/models/caption_model.dart';
import 'package:omni_bridge/data/models/subscription_models.dart';

abstract class ITranslationRepository {
  Stream<CaptionMessage>? get captions;
  void Function(double inputLevel, double outputLevel)? onAudioLevel;
  
  // Subscription / Quota support
  SubscriptionStatus? get currentQuotaStatus;
  Stream<SubscriptionStatus> get quotaStatusStream;
  String get defaultTier;

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
    String apiKey,
    String googleCredentialsJson,
    String transcriptionModel,
  });

  void liveVolumeUpdate({
    required double desktopVolume,
    required double micVolume,
  });

  Future<Map<String, dynamic>> loadDevices();
  void stop();
  Future<void> dispose();
}

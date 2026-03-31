
class FirebasePaths {
  FirebasePaths._();

  // Firestore Collections
  static const String users = 'users';
  static const String sessions = 'sessions';
  static const String usageHistory = 'usage_history';
  static const String system = 'system';
  static const String settings = 'settings';
  static const String subscriptionEvents = 'subscription_events';
  static const String feedbackTickets = 'feedback_tickets';
  static const String feedbackMessages = 'messages';

  // Firestore Documents
  static const String translationConfig = 'translation_config';
  static const String appPreferences = 'app_preferences';
  static const String monetization = 'monetization';
  static const String transcriptionConfig = 'transcription_config';
  static const String adminEmails = 'system/admins';
  static const String monetizationConfig = 'system/monetization';
  static const String appVersion = 'system/app_version';

  // RTDB Nodes
  static const String dailyUsage = 'daily_usage';
  static const String usageTotals = 'usage/totals';
  static const String captions = 'captions';
  static const String modelStats = 'model_stats';
  static const String activeSessions = 'sessions';
  static const String currentCaption = 'current_caption';

  // Storage Paths
  static const String feedbackAttachments = 'feedback_attachments';

  // Base URLs
  static const String rtdbBaseUrl =
      'https://omni-bridge-ai-translator-default-rtdb.firebaseio.com';

  /// Helper to get user-scoped Firestore collection
  static String userSettings(String uid) => '$users/$uid/$settings';
  static String userSessions(String uid) => '$users/$uid/$sessions';
  static String userUsageHistory(String uid) => '$users/$uid/$usageHistory';
  static String userCaptions(String uid) => '$users/$uid/$captions';
  static String userDailyUsage(String uid) => '$users/$uid/$dailyUsage';
  static String userFeedbackAttachments(String uid) => '$feedbackAttachments/$uid';

  // Firestore Collections (Additional)
  static const String legal = 'legal';
}

class SubscriptionPlan {
  final String id;
  final String name;
  final String price;
  final String description;
  final List<String> features;
  final bool isPopular;
  final int dailyTokens;
  final int monthlyTokens;
  final List<String> allowedTranslationModels;
  final List<String> allowedTranscriptionModels;
  final int requestsPerMinute;
  final int concurrentSessions;

  /// Per-engine monthly token limits. Key = engine id, value = monthly cap.
  final Map<String, int> engineLimits;

  /// Whether this plan is a one-time trial.
  final bool isTrial;

  /// Trial duration in hours (only relevant when [isTrial] is true).
  final int trialDurationHours;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.features,
    this.isPopular = false,
    this.isTrial = false,
    this.trialDurationHours = 24,
    this.dailyTokens = 0,
    this.monthlyTokens = 0,
    this.allowedTranslationModels = const [],
    this.allowedTranscriptionModels = const [],
    this.requestsPerMinute = 0,
    this.concurrentSessions = 1,
    this.engineLimits = const {},
  });

  bool get isUnlimited => dailyTokens < 0;
}

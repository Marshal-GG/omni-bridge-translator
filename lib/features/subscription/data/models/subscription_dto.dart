import 'package:equatable/equatable.dart';

class SubscriptionStatus extends Equatable {
  final String tier;
  final int dailyTokensUsed;
  final int weeklyTokensUsed;
  final int monthlyTokensUsed;
  final int lifetimeTokensUsed;
  final int dailyLimit;
  final DateTime dailyResetAt;

  /// For time-limited tiers (e.g. trial): total token pool for the whole period.
  /// 0 = not applicable (use daily limit instead).
  final int periodLimit;

  const SubscriptionStatus({
    required this.tier,
    required this.dailyTokensUsed,
    required this.weeklyTokensUsed,
    required this.monthlyTokensUsed,
    required this.lifetimeTokensUsed,
    required this.dailyLimit,
    required this.dailyResetAt,
    this.periodLimit = 0,
  });

  @override
  List<Object?> get props => [
        tier,
        dailyTokensUsed,
        weeklyTokensUsed,
        monthlyTokensUsed,
        lifetimeTokensUsed,
        dailyLimit,
        dailyResetAt,
        periodLimit,
      ];

  bool get hasPeriodLimit => periodLimit > 0;
  bool get isUnlimited => dailyLimit < 0 && !hasPeriodLimit;
  double get progress => hasPeriodLimit
      ? (periodLimit <= 0 ? 0 : monthlyTokensUsed / periodLimit)
      : (dailyLimit <= 0 ? 0 : dailyTokensUsed / dailyLimit);
  bool get isExceeded =>
      (hasPeriodLimit && monthlyTokensUsed >= periodLimit) ||
      (!isUnlimited && !hasPeriodLimit && dailyTokensUsed >= dailyLimit);

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      tier: json['tier'] as String? ?? '',
      dailyTokensUsed: json['dailyTokensUsed'] as int? ?? 0,
      weeklyTokensUsed: json['weeklyTokensUsed'] as int? ?? 0,
      monthlyTokensUsed: json['monthlyTokensUsed'] as int? ?? 0,
      lifetimeTokensUsed: json['lifetimeTokensUsed'] as int? ?? 0,
      dailyLimit: json['dailyLimit'] as int? ?? 0,
      dailyResetAt: json['dailyResetAt'] != null
          ? DateTime.parse(json['dailyResetAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tier': tier,
      'dailyTokensUsed': dailyTokensUsed,
      'weeklyTokensUsed': weeklyTokensUsed,
      'monthlyTokensUsed': monthlyTokensUsed,
      'lifetimeTokensUsed': lifetimeTokensUsed,
      'dailyLimit': dailyLimit,
      'dailyResetAt': dailyResetAt.toIso8601String(),
    };
  }
}

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
  /// Engines not in this map follow overall quotas only (unlimited within plan).
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

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      price: json['price'] as String,
      description: json['description'] as String,
      features: List<String>.from(json['features'] ?? []),
      isPopular: json['isPopular'] as bool? ?? false,
      isTrial: json['isTrial'] as bool? ?? false,
      trialDurationHours: json['trialDurationHours'] as int? ?? 24,
      dailyTokens: json['dailyTokens'] as int? ?? 0,
      monthlyTokens: json['monthlyTokens'] as int? ?? 0,
      allowedTranslationModels: List<String>.from(
        json['allowedTranslationModels'] ?? [],
      ),
      allowedTranscriptionModels: List<String>.from(
        json['allowedTranscriptionModels'] ?? [],
      ),
      requestsPerMinute: json['requestsPerMinute'] as int? ?? 0,
      concurrentSessions: json['concurrentSessions'] as int? ?? 1,
      engineLimits:
          (json['engineLimits'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toInt()),
          ) ??
          const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'description': description,
      'features': features,
      'isPopular': isPopular,
      'isTrial': isTrial,
      'trialDurationHours': trialDurationHours,
      'dailyTokens': dailyTokens,
      'monthlyTokens': monthlyTokens,
      'allowedTranslationModels': allowedTranslationModels,
      'allowedTranscriptionModels': allowedTranscriptionModels,
      'requestsPerMinute': requestsPerMinute,
      'concurrentSessions': concurrentSessions,
      'engineLimits': engineLimits,
    };
  }
}

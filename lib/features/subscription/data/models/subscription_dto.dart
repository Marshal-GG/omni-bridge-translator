import 'package:equatable/equatable.dart';

class SubscriptionPlan extends Equatable {
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
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: json['price'] as String? ?? '',
      description: json['description'] as String? ?? '',
      features: List<String>.from(json['features'] ?? []),
      isPopular: json['isPopular'] as bool? ?? false,
      isTrial: json['isTrial'] as bool? ?? false,
      trialDurationHours: json['trialDurationHours'] as int? ?? 24,
      dailyTokens: (json['dailyTokens'] as num?)?.toInt() ?? 0,
      monthlyTokens: (json['monthlyTokens'] as num?)?.toInt() ?? 0,
      allowedTranslationModels: List<String>.from(
        json['allowedTranslationModels'] ?? [],
      ),
      allowedTranscriptionModels: List<String>.from(
        json['allowedTranscriptionModels'] ?? [],
      ),
      requestsPerMinute: (json['requestsPerMinute'] as num?)?.toInt() ?? 0,
      concurrentSessions: (json['concurrentSessions'] as num?)?.toInt() ?? 1,
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

  @override
  List<Object?> get props => [
        id,
        name,
        price,
        description,
        features,
        isPopular,
        isTrial,
        trialDurationHours,
        dailyTokens,
        monthlyTokens,
        allowedTranslationModels,
        allowedTranscriptionModels,
        requestsPerMinute,
        concurrentSessions,
        engineLimits,
      ];
}

import '../../domain/entities/subscription_plan.dart';

class SubscriptionPlanModel extends SubscriptionPlan {
  const SubscriptionPlanModel({
    required super.id,
    required super.name,
    required super.price,
    required super.description,
    required super.features,
    super.isPopular = false,
    super.isTrial = false,
    super.trialDurationHours = 24,
    super.dailyTokens = 0,
    super.monthlyTokens = 0,
    super.allowedTranslationModels = const [],
    super.allowedTranscriptionModels = const [],
    super.requestsPerMinute = 0,
    super.concurrentSessions = 1,
    super.engineLimits = const {},
  });

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlanModel(
      id: json['id'] as String,
      name: json['name'] as String,
      price: json['price'] as String,
      description: json['description'] as String,
      features: List<String>.from(json['features'] ?? []),
      isPopular: json['isPopular'] as bool? ?? false,
      isTrial: json['isTrial'] as bool? ?? false,
      trialDurationHours: (json['trialDurationHours'] as num?)?.toInt() ?? 24,
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
      engineLimits: (json['engineLimits'] as Map<String, dynamic>?)?.map(
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

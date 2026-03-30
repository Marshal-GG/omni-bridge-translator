import '../../domain/entities/subscription_status.dart';

class SubscriptionStatusModel extends SubscriptionStatus {
  const SubscriptionStatusModel({
    required super.tier,
    required super.dailyTokensUsed,
    required super.weeklyTokensUsed,
    required super.monthlyTokensUsed,
    required super.lifetimeTokensUsed,
    required super.dailyLimit,
    required super.dailyResetAt,
    super.monthlyLimit = 0,
    super.periodLimit = 0,
  });

  factory SubscriptionStatusModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatusModel(
      tier: json['tier'] as String? ?? '',
      dailyTokensUsed: (json['dailyTokensUsed'] as num?)?.toInt() ?? 0,
      weeklyTokensUsed: (json['weeklyTokensUsed'] as num?)?.toInt() ?? 0,
      monthlyTokensUsed: (json['monthlyTokensUsed'] as num?)?.toInt() ?? 0,
      lifetimeTokensUsed: (json['lifetimeTokensUsed'] as num?)?.toInt() ?? 0,
      dailyLimit: (json['dailyLimit'] as num?)?.toInt() ?? 0,
      monthlyLimit: (json['monthlyLimit'] as num?)?.toInt() ?? 0,
      dailyResetAt: json['dailyResetAt'] != null
          ? DateTime.parse(json['dailyResetAt'] as String)
          : DateTime.now(),
      periodLimit: (json['periodLimit'] as num?)?.toInt() ?? 0,
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
      'monthlyLimit': monthlyLimit,
      'dailyResetAt': dailyResetAt.toIso8601String(),
      'periodLimit': periodLimit,
    };
  }
}

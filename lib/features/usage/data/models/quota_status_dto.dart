import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';

class QuotaStatusDto extends QuotaStatus {
  const QuotaStatusDto({
    required super.tier,
    required super.dailyTokensUsed,
    required super.weeklyTokensUsed,
    required super.monthlyTokensUsed,
    required super.lifetimeTokensUsed,
    required super.dailyLimit,
    required super.dailyResetAt,
    super.monthlyResetAt,
    super.monthlyLimit = 0,
    super.periodLimit = 0,
  });

  factory QuotaStatusDto.fromJson(
    Map<String, dynamic> json, {
    required String tier,
    required int dailyLimit,
    required int periodLimit,
    required DateTime dailyResetAt,
    DateTime? monthlyResetAt,
  }) {
    return QuotaStatusDto(
      tier: tier,
      dailyTokensUsed: (json['daily'] as num?)?.toInt() ?? 0,
      weeklyTokensUsed: (json['weekly'] as num?)?.toInt() ?? 0,
      monthlyTokensUsed:
          (json['subscription_monthly'] as num?)?.toInt() ??
          (json['calendar_monthly'] as num?)?.toInt() ??
          0,
      lifetimeTokensUsed: (json['lifetime'] as num?)?.toInt() ?? 0,
      dailyLimit: dailyLimit,
      periodLimit: periodLimit,
      dailyResetAt: dailyResetAt,
      monthlyResetAt: monthlyResetAt,
    );
  }
}

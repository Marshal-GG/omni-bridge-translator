import 'package:equatable/equatable.dart';
import 'package:omni_bridge/features/usage/domain/entities/daily_usage_record.dart';
import 'package:omni_bridge/features/usage/domain/entities/engine_usage.dart';
import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';

abstract class UsageState extends Equatable {
  const UsageState();

  @override
  List<Object?> get props => [];
}

class UsageInitial extends UsageState {}

class UsageLoading extends UsageState {}

class UsageLoaded extends UsageState {
  final List<EngineUsage> engineUsage;
  final List<DailyUsageRecord> dailyHistory;
  final int lifetimeTokens;
  final int monthlyTokens;
  final int asrTokens;
  final int translationTokens;
  final String tier;
  final QuotaStatus? quotaStatus;
  final String selectedTranslationEngine;
  final String selectedTranscriptionEngine;

  const UsageLoaded({
    required this.engineUsage,
    required this.dailyHistory,
    required this.lifetimeTokens,
    required this.monthlyTokens,
    required this.asrTokens,
    required this.translationTokens,
    required this.tier,
    this.quotaStatus,
    this.selectedTranslationEngine = 'google',
    this.selectedTranscriptionEngine = 'online',
  });

  @override
  List<Object?> get props => [
    engineUsage,
    dailyHistory,
    lifetimeTokens,
    monthlyTokens,
    asrTokens,
    translationTokens,
    tier,
    quotaStatus,
    selectedTranslationEngine,
    selectedTranscriptionEngine,
  ];
}

class UsageError extends UsageState {
  final String message;

  const UsageError(this.message);

  @override
  List<Object?> get props => [message];
}

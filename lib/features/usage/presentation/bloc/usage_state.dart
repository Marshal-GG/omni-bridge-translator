import 'package:equatable/equatable.dart';
import 'package:omni_bridge/features/usage/domain/entities/daily_usage_record.dart';
import 'package:omni_bridge/features/usage/domain/entities/engine_usage.dart';
import 'package:omni_bridge/features/usage/domain/entities/language_usage.dart';
import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';
import 'package:omni_bridge/features/usage/presentation/bloc/usage_event.dart';

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
  final List<LanguageUsage> languages;
  final int lifetimeTokens;
  final int monthlyTokens;
  final int weeklyTokens;
  final int asrTokens;
  final int translationTokens;
  final String tier;
  final QuotaStatus? quotaStatus;
  final String selectedTranslationEngine;
  final String selectedTranscriptionEngine;
  final UsageRange range;
  final DateTime loadedAt;
  final String? exportPath;
  final String? exportError;

  UsageLoaded({
    required this.engineUsage,
    required this.dailyHistory,
    required this.lifetimeTokens,
    required this.monthlyTokens,
    required this.weeklyTokens,
    required this.asrTokens,
    required this.translationTokens,
    required this.tier,
    this.languages = const [],
    this.quotaStatus,
    this.selectedTranslationEngine = 'google',
    this.selectedTranscriptionEngine = 'online',
    this.range = UsageRange.thirtyDays,
    DateTime? loadedAt,
    this.exportPath,
    this.exportError,
  }) : loadedAt = loadedAt ?? DateTime.now();

  UsageLoaded copyWith({
    List<EngineUsage>? engineUsage,
    List<DailyUsageRecord>? dailyHistory,
    List<LanguageUsage>? languages,
    int? lifetimeTokens,
    int? monthlyTokens,
    int? weeklyTokens,
    int? asrTokens,
    int? translationTokens,
    String? tier,
    QuotaStatus? quotaStatus,
    String? selectedTranslationEngine,
    String? selectedTranscriptionEngine,
    UsageRange? range,
    DateTime? loadedAt,
    String? exportPath,
    String? exportError,
    bool clearExportPath = false,
    bool clearExportError = false,
  }) {
    return UsageLoaded(
      engineUsage: engineUsage ?? this.engineUsage,
      dailyHistory: dailyHistory ?? this.dailyHistory,
      languages: languages ?? this.languages,
      lifetimeTokens: lifetimeTokens ?? this.lifetimeTokens,
      monthlyTokens: monthlyTokens ?? this.monthlyTokens,
      weeklyTokens: weeklyTokens ?? this.weeklyTokens,
      asrTokens: asrTokens ?? this.asrTokens,
      translationTokens: translationTokens ?? this.translationTokens,
      tier: tier ?? this.tier,
      quotaStatus: quotaStatus ?? this.quotaStatus,
      selectedTranslationEngine:
          selectedTranslationEngine ?? this.selectedTranslationEngine,
      selectedTranscriptionEngine:
          selectedTranscriptionEngine ?? this.selectedTranscriptionEngine,
      range: range ?? this.range,
      loadedAt: loadedAt ?? this.loadedAt,
      exportPath: clearExportPath ? null : (exportPath ?? this.exportPath),
      exportError: clearExportError ? null : (exportError ?? this.exportError),
    );
  }

  @override
  List<Object?> get props => [
    engineUsage,
    dailyHistory,
    languages,
    lifetimeTokens,
    monthlyTokens,
    weeklyTokens,
    asrTokens,
    translationTokens,
    tier,
    quotaStatus,
    selectedTranslationEngine,
    selectedTranscriptionEngine,
    range,
    loadedAt,
    exportPath,
    exportError,
  ];
}

class UsageError extends UsageState {
  final String message;

  const UsageError(this.message);

  @override
  List<Object?> get props => [message];
}

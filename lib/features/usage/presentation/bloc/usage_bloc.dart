import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:omni_bridge/core/utils/app_logger.dart';
import 'package:omni_bridge/features/usage/domain/entities/daily_usage_record.dart';
import 'package:omni_bridge/features/usage/domain/entities/engine_usage.dart';
import 'package:omni_bridge/features/usage/domain/entities/language_usage.dart';
import 'package:omni_bridge/features/usage/domain/usecases/get_usage_stats.dart';
import 'package:omni_bridge/features/usage/domain/usecases/get_usage_history.dart';
import 'package:omni_bridge/features/usage/domain/usecases/get_language_usage.dart';
import 'package:omni_bridge/features/usage/domain/usecases/get_quota_status.dart';
import 'package:omni_bridge/features/usage/domain/usecases/check_usage_rollover.dart';
import 'package:omni_bridge/features/usage/domain/usecases/get_selected_engines_usecase.dart';
import 'package:omni_bridge/features/usage/domain/usecases/clear_usage_cache.dart';
import 'package:omni_bridge/features/usage/presentation/bloc/usage_event.dart';
import 'package:omni_bridge/features/usage/presentation/bloc/usage_state.dart';

class UsageBloc extends Bloc<UsageEvent, UsageState> {
  final GetUsageStats _getUsageStats;
  final GetUsageHistory _getUsageHistory;
  final GetLanguageUsage _getLanguageUsage;
  final GetQuotaStatus _getQuotaStatus;
  final CheckUsageRollover _checkUsageRollover;
  final GetSelectedEnginesUseCase _getSelectedEngines;
  final ClearUsageCache _clearUsageCache;

  static const String _tag = 'UsageBloc';

  UsageBloc({
    required GetUsageStats getUsageStats,
    required GetUsageHistory getUsageHistory,
    required GetLanguageUsage getLanguageUsage,
    required GetQuotaStatus getQuotaStatus,
    required CheckUsageRollover checkUsageRollover,
    required GetSelectedEnginesUseCase getSelectedEngines,
    required ClearUsageCache clearUsageCache,
  }) : _getUsageStats = getUsageStats,
       _getUsageHistory = getUsageHistory,
       _getLanguageUsage = getLanguageUsage,
       _getQuotaStatus = getQuotaStatus,
       _checkUsageRollover = checkUsageRollover,
       _getSelectedEngines = getSelectedEngines,
       _clearUsageCache = clearUsageCache,
       super(UsageInitial()) {
    on<LoadUsageStats>(_onLoadUsageStats);
    on<SetDateRange>(_onSetDateRange);
    on<ExportCsv>(_onExportCsv);
  }

  Future<void> _onLoadUsageStats(
    LoadUsageStats event,
    Emitter<UsageState> emit,
  ) async {
    // Capture range BEFORE emitting UsageLoading — state changes after emit.
    final currentRange = state is UsageLoaded
        ? (state as UsageLoaded).range
        : UsageRange.thirtyDays;

    emit(UsageLoading());
    try {
      if (event.refresh) _clearUsageCache();

      await _checkUsageRollover();

      late UsageSummary summary;
      late List<DailyUsageRecord> history;
      late SelectedEngines engines;
      late List<LanguageUsage> languages;

      await Future.wait([
        _getUsageStats().then((v) => summary = v),
        _getUsageHistory(days: currentRange.days).then((v) => history = v),
        _getSelectedEngines().then((v) => engines = v),
        _getLanguageUsage().then((v) => languages = v),
      ]);

      final quotaStatus = _getQuotaStatus.current;

      emit(
        UsageLoaded(
          engineUsage: summary.stats,
          dailyHistory: history,
          languages: languages,
          lifetimeTokens: quotaStatus?.lifetimeTokensUsed ?? 0,
          monthlyTokens: quotaStatus?.monthlyTokensUsed ?? 0,
          weeklyTokens: quotaStatus?.weeklyTokensUsed ?? 0,
          asrTokens: summary.asrTokens,
          translationTokens: summary.translationTokens,
          tier: quotaStatus?.tier.toUpperCase() ?? 'FREE',
          quotaStatus: quotaStatus,
          selectedTranslationEngine: engines.translationStatsKey,
          selectedTranscriptionEngine: engines.transcriptionStatsKey,
          range: currentRange,
        ),
      );
    } catch (e) {
      emit(UsageError(e.toString()));
    }
  }

  Future<void> _onSetDateRange(
    SetDateRange event,
    Emitter<UsageState> emit,
  ) async {
    final current = state;
    if (current is! UsageLoaded) return;
    if (current.range == event.range) return;

    emit(UsageLoading());
    try {
      _clearUsageCache();
      final effectiveDays = event.range.days > 90 ? 90 : event.range.days;

      late List<DailyUsageRecord> history;
      late List<LanguageUsage> languages;

      await Future.wait([
        _getUsageHistory(days: effectiveDays).then((v) => history = v),
        _getLanguageUsage().then((v) => languages = v),
      ]);

      emit(
        current.copyWith(
          dailyHistory: history,
          languages: languages,
          range: event.range,
          loadedAt: DateTime.now(),
        ),
      );
    } catch (e) {
      emit(UsageError(e.toString()));
    }
  }

  Future<void> _onExportCsv(
    ExportCsv event,
    Emitter<UsageState> emit,
  ) async {
    final current = state;
    if (current is! UsageLoaded) return;

    try {
      final csv = _buildCsv(current);
      final home =
          Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'] ??
          '';
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final filePath = '$home\\Downloads\\omni-bridge-usage-$dateStr.csv';
      await File(filePath).writeAsString(csv);
      AppLogger.i('Usage CSV exported to $filePath', tag: _tag);
      emit(current.copyWith(exportPath: filePath, clearExportError: true));
    } catch (e) {
      AppLogger.e('Failed to export usage CSV', tag: _tag, error: e);
      emit(current.copyWith(exportError: e.toString(), clearExportPath: true));
    }
  }

  String _buildCsv(UsageLoaded state) {
    final buf = StringBuffer();
    buf.writeln('# Omni Bridge Usage Export — ${DateFormat('yyyy-MM-dd').format(DateTime.now())}');
    buf.writeln('# Tier: ${state.tier}');
    buf.writeln();

    buf.writeln('ENGINE,TYPE,TOTAL_TOKENS,TOTAL_CALLS,AVG_LATENCY_MS');
    for (final e in state.engineUsage) {
      final type = e.type == UsageType.asr ? 'ASR' : 'Translation';
      final avgMs =
          e.totalCalls > 0 ? (e.totalLatencyMs / e.totalCalls).round() : 0;
      buf.writeln('${e.engine},$type,${e.effectiveTokens},${e.totalCalls},$avgMs');
    }
    buf.writeln();

    buf.writeln('DATE,TOTAL_TOKENS');
    for (final d in state.dailyHistory) {
      final dateStr = DateFormat('yyyy-MM-dd').format(d.date);
      buf.writeln('$dateStr,${d.totalTokens}');
    }
    buf.writeln();

    if (state.languages.isNotEmpty) {
      buf.writeln('LANGUAGE,TOKENS,CALLS');
      for (final l in state.languages) {
        buf.writeln('${l.code},${l.tokens},${l.calls}');
      }
    }

    return buf.toString();
  }
}

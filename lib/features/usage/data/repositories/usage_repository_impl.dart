import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:omni_bridge/core/network/rtdb_client.dart';
import 'package:omni_bridge/features/usage/domain/entities/daily_usage_record.dart';
import 'package:omni_bridge/features/usage/domain/entities/engine_usage.dart';
import 'package:omni_bridge/features/usage/domain/repositories/usage_repository.dart';
import 'package:omni_bridge/features/subscription/domain/entities/subscription_status.dart';
import 'package:omni_bridge/features/subscription/domain/repositories/i_subscription_repository.dart';
import 'package:omni_bridge/features/subscription/data/datasources/subscription_remote_datasource.dart';

class UsageRepositoryImpl implements UsageRepository {
  final RTDBClient _rtdbClient;
  final ISubscriptionRepository _subscriptionRepository;

  UsageRepositoryImpl({
    RTDBClient? rtdbClient,
    required ISubscriptionRepository subscriptionRepository,
  }) : _rtdbClient = rtdbClient ?? RTDBClient.instance,
       _subscriptionRepository = subscriptionRepository;

  @override
  Future<List<EngineUsage>> getModelUsageStats() async {
    try {
      final url = await _rtdbClient.getRTDBUrl('model_stats');
      if (url == null) return [];

      final response = await _rtdbClient.request(
        (client) => client.get(url),
        context: 'getModelUsageStats',
      );

      if (response == null || response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>? ?? {};
      final List<EngineUsage> stats = [];

      data.forEach((engine, value) {
        if (value is Map<String, dynamic>) {
          stats.add(EngineUsage(
            engine: engine,
            totalTokens: (value['total_tokens'] as num?)?.toInt() ?? 0,
            totalCalls: (value['total_calls'] as num?)?.toInt() ?? 0,
            totalInputTokens: (value['total_input_tokens'] as num?)?.toInt() ?? 0,
            totalOutputTokens: (value['total_output_tokens'] as num?)?.toInt() ?? 0,
            totalLatencyMs: (value['total_latency_ms'] as num?)?.toInt() ?? 0,
            type: _resolveType(engine),
            lastUsed: value['last_used'] != null
                ? DateTime.fromMillisecondsSinceEpoch(value['last_used'] as int)
                : null,
          ));
        }
      });

      return stats;
    } catch (e) {
      debugPrint('[UsageRepositoryImpl] Error fetching model stats: $e');
      return [];
    }
  }

  /// Resolves engine type using `model_overrides.{engine}.type` from
  /// monetization config (the **single source of truth**).
  ///
  /// Falls back to `_resolveTypeByName` only when:
  ///   • config hasn't loaded yet (cold start), or
  ///   • the engine key is missing from `model_overrides`.
  UsageType _resolveType(String engine) {
    final src = SubscriptionRemoteDataSource.instance;
    final configType = src.getModelType(engine);

    if (configType != null) {
      switch (configType) {
        case 'asr':
          return UsageType.asr;
        case 'translation':
          return UsageType.translation;
      }
    }

    // Fallback: config not loaded or engine not in model_overrides.
    return _resolveTypeByName(engine);
  }

  /// Startup / unknown-engine fallback.  Deterministic type resolution by
  /// engine key name patterns — only reached when config is unavailable.
  ///
  /// **Order matters**: ASR-specific patterns are checked first so that keys
  /// like `riva-asr` are correctly classified as ASR before
  /// the `riva-nmt` match hits the translation branch.
  UsageType _resolveTypeByName(String engine) {
    final name = engine.toLowerCase();

    // Skip no-op / same-language placeholder entries.
    if (name == 'no-op' || name == 'noop') return UsageType.unknown;

    // ── ASR-specific patterns (checked first for priority) ──────────
    if (name == 'online' ||
        name.contains('whisper') ||
        name.contains('asr') ||
        name.contains('parakeet') ||
        name.contains('canary') ||
        name.contains('stt') ||
        name == 'deepgram') {
      return UsageType.asr;
    }

    // ── Translation-specific patterns ───────────────────────────────
    if (name == 'google' ||
        name == 'google_api' ||
        name.contains('google-cloud') ||
        name.contains('v3-grpc') ||
        name.contains('translate') ||
        name == 'mymemory' ||
        name.contains('mymemory') ||
        name == 'llama' ||
        name.contains('llama') ||
        name == 'riva-nmt' ||
        name.contains('nmt') ||
        name.contains('grpc-mt')) {
      return UsageType.translation;
    }

    return UsageType.unknown;
  }

  @override
  Future<List<DailyUsageRecord>> getDailyUsageHistory({int days = 30}) async {
    try {
      final url = await _rtdbClient.getRTDBUrl('daily_usage');
      if (url == null) return [];

      final response = await _rtdbClient.request(
        (client) => client.get(url),
        context: 'getDailyUsageHistory',
      );

      if (response == null || response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>? ?? {};
      final List<DailyUsageRecord> history = [];

      final sortedKeys = data.keys.toList()..sort((a, b) => b.compareTo(a));
      final limitKeys = sortedKeys.take(days).toList();

      for (final dateStr in limitKeys) {
        final dayData = data[dateStr] as Map<String, dynamic>?;
        if (dayData == null) continue;

        final engineTokens = <String, int>{};
        final modelsData = dayData['models'] as Map<String, dynamic>? ?? {};
        modelsData.forEach((engine, val) {
          if (val is Map<String, dynamic>) {
            engineTokens[engine] = (val['tokens'] as num?)?.toInt() ?? 0;
          }
        });

        history.add(DailyUsageRecord(
          date: DateTime.parse(dateStr),
          totalTokens: (dayData['tokens'] as num?)?.toInt() ?? 0,
          engineTokens: engineTokens,
        ));
      }

      return history.reversed.toList();
    } catch (e) {
      debugPrint('[UsageRepositoryImpl] Error fetching daily history: $e');
      return [];
    }
  }

  @override
  Future<SubscriptionStatus?> getSubscriptionStatus() async {
    return _subscriptionRepository.currentStatus;
  }
}

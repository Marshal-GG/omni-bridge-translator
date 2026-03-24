import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:omni_bridge/core/network/rtdb_client.dart';
import 'package:omni_bridge/features/usage/domain/entities/daily_usage_record.dart';
import 'package:omni_bridge/features/usage/domain/entities/engine_usage.dart';
import 'package:omni_bridge/features/usage/domain/repositories/usage_repository.dart';
import 'package:omni_bridge/features/subscription/domain/entities/subscription_status.dart';
import 'package:omni_bridge/features/subscription/domain/repositories/i_subscription_repository.dart';

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

  UsageType _resolveType(String engine) {
    final name = engine.toLowerCase();

    // ASR / Transcription Engines
    if (name.contains('whisper') ||
        name.contains('riva') ||
        name.contains('deepgram') ||
        name.contains('parakeet') ||
        name.contains('canary') ||
        name.contains('stt') ||
        name == 'asr') {
      return UsageType.asr;
    }

    // Translation Engines
    if (name.contains('openai') ||
        name.contains('anthropic') ||
        name.contains('google') ||
        name.contains('groq') ||
        name.contains('together') ||
        name.contains('claude') ||
        name.contains('gpt') ||
        name == 'translation' ||
        name == 'translator') {
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

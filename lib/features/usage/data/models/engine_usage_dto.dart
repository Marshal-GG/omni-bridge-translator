import 'package:omni_bridge/features/usage/domain/entities/engine_usage.dart';
import 'package:omni_bridge/features/subscription/data/datasources/subscription_remote_datasource.dart';

class EngineUsageDto extends EngineUsage {
  const EngineUsageDto({
    required super.engine,
    required super.totalTokens,
    required super.totalCalls,
    required super.totalInputTokens,
    required super.totalOutputTokens,
    required super.totalLatencyMs,
    required super.type,
    super.lastUsed,
    super.monthlyTokensUsed = -1,
    super.monthlyTokensLimit = -1,
    super.isInPlan = false,
  });

  factory EngineUsageDto.fromJson(String engine, Map<String, dynamic> json) {
    return EngineUsageDto(
      engine: engine,
      totalTokens: (json['total_tokens'] as num?)?.toInt() ?? 0,
      totalCalls: (json['total_calls'] as num?)?.toInt() ?? 0,
      totalInputTokens: (json['total_input_tokens'] as num?)?.toInt() ?? 0,
      totalOutputTokens: (json['total_output_tokens'] as num?)?.toInt() ?? 0,
      totalLatencyMs: (json['total_latency_ms'] as num?)?.toInt() ?? 0,
      type: resolveType(engine),
      lastUsed: json['last_used'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['last_used'] as int)
          : null,
    );
  }

  static UsageType resolveType(String engine) {
    final src = SubscriptionRemoteDataSource.instance;
    final configType = src.getModelType(engine);

    if (configType != null) {
      if (configType == 'asr') return UsageType.asr;
      if (configType == 'translation') return UsageType.translation;
    }

    final name = engine.toLowerCase();
    if (name == 'no-op' || name == 'noop') return UsageType.unknown;

    if (name == 'online' ||
        name.contains('whisper') ||
        name.contains('asr') ||
        name.contains('parakeet') ||
        name.contains('canary') ||
        name.contains('stt') ||
        name == 'deepgram') {
      return UsageType.asr;
    }

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
}

import 'package:equatable/equatable.dart';

enum UsageType { asr, translation, unknown }

class EngineUsage extends Equatable {
  final String engine;
  final int totalTokens;
  final int totalCalls;
  final int totalInputTokens;
  final int totalOutputTokens;
  final int totalLatencyMs;
  final DateTime? lastUsed;
  final UsageType type;

  const EngineUsage({
    required this.engine,
    required this.totalTokens,
    required this.totalCalls,
    required this.totalInputTokens,
    required this.totalOutputTokens,
    required this.totalLatencyMs,
    required this.type,
    this.lastUsed,
  });

  double get averageLatencyMs => totalCalls > 0 ? totalLatencyMs / totalCalls : 0;

  @override
  List<Object?> get props => [
        engine,
        totalTokens,
        totalCalls,
        totalInputTokens,
        totalOutputTokens,
        totalLatencyMs,
        lastUsed,
        type,
      ];
}

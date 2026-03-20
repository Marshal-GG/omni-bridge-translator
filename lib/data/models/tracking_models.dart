import 'package:cloud_firestore/cloud_firestore.dart';

class ModelUsageStats {
  final String engine;
  final String model;
  final int latencyMs;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final int inputChars;
  final int outputChars;
  final String sourceLang;
  final String targetLang;
  final String? fallbackFrom;
  final String? error;
  final String? sessionId;
  final DateTime timestamp;

  ModelUsageStats({
    required this.engine,
    required this.model,
    required this.latencyMs,
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    required this.inputChars,
    required this.outputChars,
    required this.sourceLang,
    required this.targetLang,
    this.fallbackFrom,
    this.error,
    this.sessionId,
    required this.timestamp,
  });

  factory ModelUsageStats.fromJson(Map<String, dynamic> json) {
    return ModelUsageStats(
      engine: json['engine'] as String? ?? 'unknown',
      model: json['model'] as String? ?? 'unknown',
      latencyMs: (json['latency_ms'] as num?)?.toInt() ?? 0,
      promptTokens: (json['prompt_tokens'] as num?)?.toInt() ?? 0,
      completionTokens: (json['completion_tokens'] as num?)?.toInt() ?? 0,
      totalTokens: (json['total_tokens'] as num?)?.toInt() ?? 0,
      inputChars: (json['input_chars'] as num?)?.toInt() ?? 0,
      outputChars: (json['output_chars'] as num?)?.toInt() ?? 0,
      sourceLang: json['source_lang'] as String? ?? 'unknown',
      targetLang: json['target_lang'] as String? ?? 'unknown',
      fallbackFrom: json['fallback_from'] as String?,
      error: json['error'] as String?,
      sessionId: json['sessionId'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'engine': engine,
      'model': model,
      'latency_ms': latencyMs,
      'prompt_tokens': promptTokens,
      'completion_tokens': completionTokens,
      'total_tokens': totalTokens,
      'input_chars': inputChars,
      'output_chars': outputChars,
      'source_lang': sourceLang,
      'target_lang': targetLang,
      'fallback_from': fallbackFrom,
      'error': error,
      'sessionId': sessionId,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

class SessionData {
  final String sessionId;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationSeconds;
  final bool isEnded;
  final bool forceLogout;
  final Map<String, dynamic> device;

  SessionData({
    required this.sessionId,
    required this.startTime,
    this.endTime,
    required this.durationSeconds,
    required this.isEnded,
    required this.forceLogout,
    required this.device,
  });

  factory SessionData.fromJson(Map<String, dynamic> json) {
    return SessionData(
      sessionId: json['sessionId'] as String,
      startTime: (json['startTime'] as Timestamp).toDate(),
      endTime: (json['endTime'] as Timestamp?)?.toDate(),
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      isEnded: json['isEnded'] as bool? ?? false,
      forceLogout: json['forceLogout'] as bool? ?? false,
      device: Map<String, dynamic>.from(json['device'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'startTime': startTime,
      'endTime': endTime,
      'durationSeconds': durationSeconds,
      'isEnded': isEnded,
      'forceLogout': forceLogout,
      'device': device,
    };
  }
}

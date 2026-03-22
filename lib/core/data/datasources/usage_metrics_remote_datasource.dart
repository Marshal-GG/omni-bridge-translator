import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:omni_bridge/core/network/rtdb_client.dart';
import 'package:omni_bridge/core/data/datasources/data_maintenance_remote_datasource.dart';

class UsageMetricsRemoteDataSource {
  UsageMetricsRemoteDataSource._();
  static final UsageMetricsRemoteDataSource instance = UsageMetricsRemoteDataSource._();

  static final String _appName = kDebugMode
      ? 'OmniBridge-Debug'
      : 'OmniBridge-Release';
  FirebaseApp get _app => Firebase.app(_appName);
  FirebaseAuth get _auth => FirebaseAuth.instanceFor(app: _app);

  final RTDBClient _rtdbClient = RTDBClient.instance;

  // Buffer for aggregating usage stats to reduce RTDB writes
  final Map<String, dynamic> _usageBuffer = {};
  Timer? _usageFlushTimer;

  String? get uid => _auth.currentUser?.uid;

  /// Initialize metrics by running cleanup routines
  void initialize() {
    unawaited(DataMaintenanceRemoteDataSource.instance.cleanupOldCaptions());
    unawaited(DataMaintenanceRemoteDataSource.instance.cleanupOldDailyUsage());
    unawaited(DataMaintenanceRemoteDataSource.instance.cleanupOldSessions());
  }

  /// Log a general app event
  Future<void> logEvent(String eventName, [Map<String, dynamic>? data]) async {
    debugPrint('[UsageMetrics] Event: $eventName${data != null ? ' $data' : ''}');
  }

  /// Buffers usage stats and aggregates them to reduce RTDB writes.
  void logModelUsage(Map<String, dynamic> stats) {
    try {
      final engine = stats['engine'] as String? ?? 'unknown';
      final inputTokens = (stats['input_tokens'] as num?)?.toInt() ?? 0;
      final outputTokens = (stats['output_tokens'] as num?)?.toInt() ?? 0;
      final latencyMs = (stats['latency_ms'] as num?)?.toInt() ?? 0;

      _usageBuffer[engine] ??= {
        'total_tokens': 0,
        'input_tokens': 0,
        'output_tokens': 0,
        'latency_ms': 0,
        'calls': 0,
        'last_model': stats['model'],
        'last_error': stats['error'],
      };

      final b = _usageBuffer[engine];
      b['total_tokens'] += (inputTokens + outputTokens);
      b['input_tokens'] += inputTokens;
      b['output_tokens'] += outputTokens;
      b['latency_ms'] += latencyMs;
      b['calls'] += 1;
      b['last_model'] = stats['model'];
      if (stats['error'] != null) b['last_error'] = stats['error'];

      _usageFlushTimer?.cancel();
      _usageFlushTimer = Timer(const Duration(seconds: 3), () => flushUsage());

      debugPrint(
        '[UsageMetrics] Buffered model usage: $engine (+$inputTokens/+$outputTokens tokens)',
      );
    } catch (e) {
      debugPrint('[UsageMetrics] Error buffering model usage: $e');
    }
  }

  /// Flushes all buffered usage stats to RTDB in a single multi-path PATCH.
  Future<void> flushUsage() async {
    if (_usageBuffer.isEmpty) return;
    _usageFlushTimer?.cancel();

    final Map<String, dynamic> bufferCopy = Map.from(_usageBuffer);
    _usageBuffer.clear();

    final userUid = uid;
    if (userUid == null) return;

    try {
      final url = await _rtdbClient.getAbsoluteUrl('users/$userUid');
      if (url == null) return;

      final Map<String, dynamic> updates = {};
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      int totalDailyTokens = 0;

      for (final entry in bufferCopy.entries) {
        final engine = entry.key;
        final data = entry.value;

        updates['model_stats/$engine/total_calls'] = {
          '.sv': {'increment': data['calls']},
        };
        updates['model_stats/$engine/total_tokens'] = {
          '.sv': {'increment': data['total_tokens']},
        };
        updates['model_stats/$engine/total_input_tokens'] = {
          '.sv': {'increment': data['input_tokens']},
        };
        updates['model_stats/$engine/total_output_tokens'] = {
          '.sv': {'increment': data['output_tokens']},
        };
        updates['model_stats/$engine/total_latency_ms'] = {
          '.sv': {'increment': data['latency_ms']},
        };
        updates['model_stats/$engine/last_used'] = {'.sv': 'timestamp'};
        updates['model_stats/$engine/engine'] = engine;

        if (data['total_tokens'] > 0) {
          updates['daily_usage/$todayStr/tokens'] = {
            '.sv': {'increment': data['total_tokens']},
          };
          updates['daily_usage/$todayStr/last_updated'] = {'.sv': 'timestamp'};
          updates['daily_usage/$todayStr/models/$engine/tokens'] = {
            '.sv': {'increment': data['total_tokens']},
          };
          updates['daily_usage/$todayStr/models/$engine/calls'] = {
            '.sv': {'increment': data['calls']},
          };
          updates['daily_usage/$todayStr/models/$engine/last_updated'] = {
            '.sv': 'timestamp',
          };
          totalDailyTokens += data['total_tokens'] as int;
        }

        if (data['last_error'] != null) {
          updates['daily_usage/$todayStr/errors/$engine/failed_calls'] = {
            '.sv': {'increment': data['calls']},
          };
          updates['daily_usage/$todayStr/errors/$engine/last_error'] =
              data['last_error'];
          updates['daily_usage/$todayStr/errors/$engine/last_error_time'] = {
            '.sv': 'timestamp',
          };
        }
      }

      if (totalDailyTokens > 0) {
        updates['usage/totals/lifetime'] = {
          '.sv': {'increment': totalDailyTokens},
        };
        updates['usage/totals/calendar_monthly'] = {
          '.sv': {'increment': totalDailyTokens},
        };
        updates['usage/totals/subscription_monthly'] = {
          '.sv': {'increment': totalDailyTokens},
        };
        updates['usage/totals/weekly'] = {
          '.sv': {'increment': totalDailyTokens},
        };
      }

      if (updates.isNotEmpty) {
        await _rtdbClient.request(
          (client) => client.patch(url, body: jsonEncode(updates)),
          context: 'flushUsage',
        );
        debugPrint(
          '[UsageMetrics] Flushed usage stats to RTDB (+$totalDailyTokens tokens).',
        );
      }
    } catch (e) {
      debugPrint('[UsageMetrics] Failed to flush usage to RTDB: $e');
    }
  }

  /// Resets the singleton state. Called on logout.
  Future<void> reset() async {
    _usageFlushTimer?.cancel();
    _usageFlushTimer = null;
    _usageBuffer.clear();
    debugPrint('[UsageMetrics] state reset');
  }
}

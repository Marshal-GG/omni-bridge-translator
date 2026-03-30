import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:omni_bridge/core/data/datasources/data_maintenance_remote_datasource.dart';
import 'package:omni_bridge/core/network/rtdb_client.dart';

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

      _usageFlushTimer ??= Timer(const Duration(seconds: 3), () => flushUsage());

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
    _usageFlushTimer = null;

    final Map<String, dynamic> bufferCopy = Map.from(_usageBuffer);
    _usageBuffer.clear();

    final userUid = uid;
    if (userUid == null) return;

    try {
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // 1. Fetch current totals to perform client-side increments (REST API limitation)
      final rootUrl = await _rtdbClient.getRTDBUrl('');
      if (rootUrl == null) return;

      final getResp = await _rtdbClient.request(
        (client) => client.get(rootUrl),
        context: 'flushUsage:fetch',
      );

      Map<String, dynamic> currentData = {};
      if (getResp != null && getResp.statusCode == 200) {
        currentData = jsonDecode(getResp.body) as Map<String, dynamic>? ?? {};
      }

      final Map<String, dynamic> updates = {};
      int totalDailyTokens = 0;

      for (final entry in bufferCopy.entries) {
        final engine = entry.key;
        final data = entry.value;

        // Model Stats Base
        final modelStats = currentData['model_stats']?[engine] as Map<String, dynamic>? ?? {};
        
        updates['model_stats/$engine/total_calls'] = (modelStats['total_calls'] ?? 0) + data['calls'];
        updates['model_stats/$engine/total_tokens'] = (modelStats['total_tokens'] ?? 0) + data['total_tokens'];
        updates['model_stats/$engine/total_input_tokens'] = (modelStats['total_input_tokens'] ?? 0) + data['input_tokens'];
        updates['model_stats/$engine/total_output_tokens'] = (modelStats['total_output_tokens'] ?? 0) + data['output_tokens'];
        updates['model_stats/$engine/total_latency_ms'] = (modelStats['total_latency_ms'] ?? 0) + data['latency_ms'];
        updates['model_stats/$engine/last_used'] = {".sv": "timestamp"};
        updates['model_stats/$engine/engine'] = engine;

        if (data['total_tokens'] > 0) {
          final dailyModel = currentData['daily_usage']?[todayStr]?['models']?[engine] as Map<String, dynamic>? ?? {};
          updates['daily_usage/$todayStr/models/$engine/tokens'] = (dailyModel['tokens'] ?? 0) + data['total_tokens'];
          updates['daily_usage/$todayStr/models/$engine/calls'] = (dailyModel['calls'] ?? 0) + data['calls'];
          updates['daily_usage/$todayStr/models/$engine/last_updated'] = {".sv": "timestamp"};

          final totalsBase = currentData['usage']?['totals'] as Map<String, dynamic>? ?? {};
          final subModelsBase = totalsBase['subscription_monthly_models'] as Map<String, dynamic>? ?? {};
          final currentEngineMonth = (subModelsBase[engine] as num?)?.toInt() ?? 0;
          updates['usage/totals/subscription_monthly_models/$engine'] = currentEngineMonth + data['total_tokens'];

          totalDailyTokens += data['total_tokens'] as int;
        }

        if (data['last_error'] != null) {
          final dailyError = currentData['daily_usage']?[todayStr]?['errors']?[engine] as Map<String, dynamic>? ?? {};
          updates['daily_usage/$todayStr/errors/$engine/failed_calls'] = (dailyError['failed_calls'] ?? 0) + data['calls'];
          updates['daily_usage/$todayStr/errors/$engine/last_error'] = data['last_error'];
          updates['daily_usage/$todayStr/errors/$engine/last_error_time'] = {".sv": "timestamp"};
        }
      }

      if (totalDailyTokens > 0) {
        final dailyBase = currentData['daily_usage']?[todayStr] as Map<String, dynamic>? ?? {};
        final totalsBase = currentData['usage']?['totals'] as Map<String, dynamic>? ?? {};

        updates['daily_usage/$todayStr/tokens'] = (dailyBase['tokens'] ?? 0) + totalDailyTokens;
        updates['daily_usage/$todayStr/last_updated'] = {".sv": "timestamp"};
        updates['usage/totals/lifetime'] = (totalsBase['lifetime'] ?? 0) + totalDailyTokens;
        updates['usage/totals/calendar_monthly'] = (totalsBase['calendar_monthly'] ?? 0) + totalDailyTokens;
        updates['usage/totals/subscription_monthly'] = (totalsBase['subscription_monthly'] ?? 0) + totalDailyTokens;
        updates['usage/totals/weekly'] = (totalsBase['weekly'] ?? 0) + totalDailyTokens;
      }

      if (updates.isNotEmpty) {
        final patchUrl = await _rtdbClient.getRTDBUrl('');
        if (patchUrl == null) return;

        await _rtdbClient.request(
          (client) => client.patch(patchUrl, body: jsonEncode(updates)),
          context: 'flushUsage:patch',
        );
        debugPrint(
          '[UsageMetrics] Flushed usage stats to RTDB (+$totalDailyTokens tokens) via REST.',
        );
      }
    } catch (e) {
      debugPrint('[UsageMetrics] Failed to flush usage to RTDB (REST): $e');
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

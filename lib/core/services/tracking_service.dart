import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

class TrackingService {
  TrackingService._();
  static final TrackingService instance = TrackingService._();

  String? _currentSessionId;
  DateTime? _sessionStartTime;
  Timer? _heartbeatTimer;

  /// Check if a session is currently active
  bool get hasActiveSession => _currentSessionId != null;

  /// Get current user ID
  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  /// Collects device hardware and network info.
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    final info = <String, dynamic>{'platform': 'Windows Desktop'};

    try {
      final deviceInfo = DeviceInfoPlugin();
      final win = await deviceInfo.windowsInfo;
      info['computer_name'] = win.computerName;
      info['user_name'] = win.userName;
      info['os_version'] =
          '${win.majorVersion}.${win.minorVersion}.${win.buildNumber}';
      info['product_name'] = win.productName;
      info['system_memory_mb'] = win.systemMemoryInMegabytes;
    } catch (e) {
      debugPrint('[Tracking] device_info error: $e');
    }

    try {
      final net = NetworkInfo();
      info['wifi_ip'] = await net.getWifiIP() ?? 'N/A';
      info['wifi_name'] = await net.getWifiName() ?? 'N/A';
      info['wifi_bssid'] =
          await net.getWifiBSSID() ?? 'N/A'; // MAC of access point
      info['wifi_ipv6'] = await net.getWifiIPv6() ?? 'N/A';
      info['wifi_gateway'] = await net.getWifiGatewayIP() ?? 'N/A';
      info['wifi_submask'] = await net.getWifiSubmask() ?? 'N/A';
    } catch (e) {
      debugPrint('[Tracking] network_info error: $e');
    }

    return info;
  }

  /// Start an app session
  Future<void> startSession() async {
    if (uid == null) {
      debugPrint(
        '[Tracking] Cannot start session: UID is null. User not signed in.',
      );
      return;
    }

    // Prevent starting a new session if one is already actively running
    if (_currentSessionId != null) {
      debugPrint(
        '[Tracking] Session $_currentSessionId already running. Ignoring startSession call.',
      );
      return;
    }

    _sessionStartTime = DateTime.now();

    // Collect device and network info before creating the session doc
    final deviceInfo = await _getDeviceInfo();

    // Create a new master session document (could be per-launch or per-login)
    final sessionRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('sessions')
        .doc();

    _currentSessionId = sessionRef.id;

    try {
      await sessionRef.set({
        'sessionId': _currentSessionId,
        'startTime': FieldValue.serverTimestamp(),
        'lastPingAt': FieldValue.serverTimestamp(),
        'isEnded': false,
        'device': deviceInfo,
      });
      debugPrint('[Tracking] Session $_currentSessionId started');

      // Start the heartbeat to let the server know we're still alive
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
        _pingSession();
      });
    } catch (e) {
      logError('Failed to start session', e);
    }
  }

  /// End an app session
  Future<void> endSession() async {
    if (uid == null || _currentSessionId == null) {
      debugPrint('[Tracking] Cannot end session: UID or SessionID is null.');
      return;
    }

    try {
      final sessionRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('sessions')
          .doc(_currentSessionId);

      final duration = _sessionStartTime != null
          ? DateTime.now().difference(_sessionStartTime!).inSeconds
          : 0;

      await sessionRef.set({
        'endTime': FieldValue.serverTimestamp(),
        'durationSeconds': duration,
        'isEnded': true,
      }, SetOptions(merge: true));
      debugPrint('[Tracking] Session $_currentSessionId ended');
    } catch (e) {
      logError('Failed to end session', e);
    } finally {
      _currentSessionId = null;
      _sessionStartTime = null;
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
    }
  }

  /// Sends a periodic lightweight ping to the active session document
  Future<void> _pingSession() async {
    if (uid == null || _currentSessionId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('sessions')
          .doc(_currentSessionId)
          .update({
            'lastPingAt': FieldValue.serverTimestamp(),
            'durationSeconds': DateTime.now()
                .difference(_sessionStartTime!)
                .inSeconds,
          });
      debugPrint('[Tracking] Heartbeat ping sent.');
    } catch (e) {
      debugPrint('[Tracking] Failed to send heartbeat ping: $e');
    }
  }

  /// Sync current Translation Settings to Firestore
  Future<void> syncSettings(Map<String, dynamic> settingsData) async {
    if (uid == null) {
      debugPrint('[Tracking] Cannot sync settings: UID is null.');
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('app_preferences')
          .set({
            ...settingsData,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      debugPrint('[Tracking] User settings synced to Firestore.');
    } catch (e) {
      logError('Failed to sync user settings', e);
    }
  }

  /// Get current Translation Settings from Firestore
  Future<Map<String, dynamic>?> getSettings() async {
    if (uid == null) {
      debugPrint('[Tracking] Cannot fetch settings: UID is null.');
      return null;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('app_preferences')
          .get();

      if (doc.exists) {
        debugPrint('[Tracking] Fetched user settings from Firestore.');
        return doc.data();
      }
    } catch (e) {
      logError('Failed to fetch user settings', e);
    }
    return null;
  }

  /// Write general app logs and system usage information to a universal FireStore log
  Future<void> logEvent(String eventName, [Map<String, dynamic>? data]) async {
    if (uid == null) {
      debugPrint('[Tracking] Cannot log event $eventName: UID is null.');
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('logs')
          .add({
            'event': eventName,
            'data': data ?? {},
            'timestamp': FieldValue.serverTimestamp(),
            'sessionId': _currentSessionId,
          });
      debugPrint('[Tracking] Logged event: $eventName');
    } catch (e) {
      debugPrint('[Tracking] Error logging event: $e');
    }
  }

  /// Log an error to Firestore
  Future<void> logError(String message, [Object? error]) async {
    if (uid == null) {
      debugPrint('[Tracking] Cannot log error $message: UID is null.');
      return;
    }

    final errorStr = error?.toString() ?? '';
    if (message.contains('setState() called after dispose()') ||
        errorStr.contains('setState() called after dispose()')) {
      return; // Filter out noisy and harmless widget lifecycle errors
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('error_logs')
          .add({
            'message': message,
            'error': error?.toString(),
            'timestamp': FieldValue.serverTimestamp(),
            'sessionId': _currentSessionId,
          });
      debugPrint('[Tracking] Logged error: $message');
    } catch (e) {
      debugPrint('[Tracking] Failed to log error: $e');
    }
  }

  /// Push high-frequency Live Caption data to Realtime Database
  /// This prevents huge Firestore write costs for live streaming translations
  Future<void> syncLiveCaption(
    String originalText,
    String translatedText,
    String sourceLang,
    String targetLang,
    bool isFinal,
    String translationModel,
  ) async {
    if (uid == null) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();

      final url = Uri.parse(
        'https://omni-bridge-ai-translator-default-rtdb.firebaseio.com/users/$uid/captions.json?auth=$idToken',
      );

      await http.post(
        url,
        body: jsonEncode({
          'originalText': originalText,
          'translatedText': translatedText,
          'sourceLang': sourceLang,
          'targetLang': targetLang,
          'translationModel': translationModel,
          'isFinal': isFinal,
          'timestamp': {
            '.sv': 'timestamp',
          }, // RTDB ServerValue.timestamp equivalent
          'sessionId': _currentSessionId ?? 'unknown',
        }),
      );
    } catch (e) {
      // Don't log this to Firestore to avoid loop, just local console
      debugPrint('[Tracking] Error pushing live caption to RTDB REST API: $e');
    }
  }

  /// Log AI model translation usage stats to Firestore.
  /// Writes two documents per translation:
  ///  1. Individual log  → users/{uid}/model_usage/{auto-id}
  ///  2. Engine totals   → users/{uid}/model_stats/{engine}  (atomic increment)
  Future<void> logModelUsage(Map<String, dynamic> stats) async {
    if (uid == null) return;

    final engine = stats['engine'] as String? ?? 'unknown';
    final totalTokens = (stats['total_tokens'] as num?)?.toInt() ?? 0;
    final latencyMs = (stats['latency_ms'] as num?)?.toInt() ?? 0;
    final inputChars = (stats['input_chars'] as num?)?.toInt() ?? 0;
    final outputChars = (stats['output_chars'] as num?)?.toInt() ?? 0;

    final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);

    try {
      // 1. Individual usage log entry
      await userDoc.collection('model_usage').add({
        'engine': engine,
        'model': stats['model'] ?? 'unknown',
        'latency_ms': latencyMs,
        'prompt_tokens': stats['prompt_tokens'] ?? 0,
        'completion_tokens': stats['completion_tokens'] ?? 0,
        'total_tokens': totalTokens,
        'input_chars': inputChars,
        'output_chars': outputChars,
        'source_lang': stats['source_lang'] ?? 'unknown',
        'target_lang': stats['target_lang'] ?? 'unknown',
        'fallback_from': stats['fallback_from'],
        'error': stats['error'],
        'sessionId': _currentSessionId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. Per-engine running totals — atomic increments, safe for concurrent writes
      await userDoc.collection('model_stats').doc(engine).set({
        'engine': engine,
        'total_calls': FieldValue.increment(1),
        'total_tokens': FieldValue.increment(totalTokens),
        'total_latency_ms': FieldValue.increment(latencyMs),
        'total_input_chars': FieldValue.increment(inputChars),
        'total_output_chars': FieldValue.increment(outputChars),
        'last_used': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint(
        '[Tracking] Logged model usage: $engine (tokens: $totalTokens)',
      );
    } catch (e) {
      debugPrint('[Tracking] Failed to log model usage: $e');
    }
  }
}

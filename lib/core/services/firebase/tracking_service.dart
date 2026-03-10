import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../navigation/global_navigator.dart';

class TrackingService {
  TrackingService._();
  static final TrackingService instance = TrackingService._();

  String? _currentSessionId;
  DateTime? _sessionStartTime;
  Timer? _heartbeatTimer;
  StreamSubscription<DocumentSnapshot>? _sessionSub;
  StreamSubscription<DocumentSnapshot>? _userSub;

  static const String _rtdbBaseUrl =
      'https://omni-bridge-ai-translator-default-rtdb.firebaseio.com';

  /// Check if a session is currently active
  bool get hasActiveSession => _currentSessionId != null;

  /// Get current user ID
  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  /// Helper to get authenticated RTDB URL
  Future<Uri?> _getRTDBUrl(String path) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || uid == null) return null;

    final idToken = await user.getIdToken();
    return Uri.parse('$_rtdbBaseUrl/users/$uid/$path.json?auth=$idToken');
  }

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

    if (_currentSessionId != null) {
      debugPrint(
        '[Tracking] Session $_currentSessionId already running. Ignoring startSession call.',
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final cachedSessionId = prefs.getString('current_session_id_$uid');

    _sessionStartTime = DateTime.now();
    final deviceInfo = await _getDeviceInfo();

    DocumentReference? sessionRef;
    bool isNewSession = true;

    if (cachedSessionId != null) {
      sessionRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('sessions')
          .doc(cachedSessionId);

      try {
        final doc = await sessionRef.get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          if (data['isEnded'] != true && data['forceLogout'] != true) {
            isNewSession = false;
            _currentSessionId = cachedSessionId;

            await sessionRef.set({
              'appReopenedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            debugPrint(
              '[Tracking] Resumed existing session $_currentSessionId',
            );
          }
        }
      } catch (e) {
        debugPrint('[Tracking] Failed to check existing session: $e');
      }
    }

    if (isNewSession) {
      sessionRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('sessions')
          .doc();

      _currentSessionId = sessionRef.id;
      await prefs.setString('current_session_id_$uid', _currentSessionId!);

      try {
        await sessionRef.set({
          'sessionId': _currentSessionId,
          'startTime': FieldValue.serverTimestamp(),
          'isEnded': false,
          'forceLogout': false,
          'device': deviceInfo,
        });
        debugPrint('[Tracking] Session $_currentSessionId started');
      } catch (e) {
        logError('Failed to start session', e);
      }
    }

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _pingSession();
    });

    _sessionSub?.cancel();
    _sessionSub = sessionRef?.snapshots().listen((snapshot) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (snapshot.exists) {
          final data = snapshot.data();
          if (data is Map<String, dynamic> && data['forceLogout'] == true) {
            debugPrint(
              '[Tracking] Remote forceLogout detected for session $_currentSessionId',
            );
            _handleRemoteLogout();
          }
        }
      });
    });

    // Listen to User document for global forceLogout
    _userSub?.cancel();
    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (snapshot.exists) {
              final data = snapshot.data();
              if (data is Map<String, dynamic> && data['forceLogout'] == true) {
                debugPrint(
                  '[Tracking] Remote forceLogout detected for user $uid',
                );
                _handleRemoteLogout();
              }
            }
          });
        });

    // 2. Sync Initial App Settings to RTDB
    try {
      final settingsUrl = await _getRTDBUrl('sessions/$_currentSessionId');
      if (settingsUrl != null) {
        await http.patch(
          settingsUrl,
          body: jsonEncode({
            'started_at': {'.sv': 'timestamp'},
          }),
        );
      }
    } catch (e) {
      debugPrint('[Tracking] Failed to sync session start to RTDB: $e');
    }
  }

  void _handleRemoteLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_session_id_$uid');

    // Auth state listener handles the rest
    await FirebaseAuth.instance.signOut();

    // Force redirection to Splash Screen (which handles Onboarding/Login logic)
    await GlobalNavigator.pushNamedAndRemoveUntil('/splash', (route) => false);
  }

  /// End an app session
  Future<void> endSession() async {
    if (uid == null || _currentSessionId == null) {
      debugPrint('[Tracking] Cannot end session: UID or SessionID is null.');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_session_id_$uid');

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

      try {
        final settingsUrl = await _getRTDBUrl('sessions/$_currentSessionId');
        if (settingsUrl != null) {
          await http.patch(
            settingsUrl,
            body: jsonEncode({
              'ended_at': {'.sv': 'timestamp'},
              'duration_seconds': duration,
            }),
          );
        }
      } catch (e) {
        debugPrint('[Tracking] Failed to sync session end to RTDB: $e');
      }

      debugPrint('[Tracking] Session $_currentSessionId ended');
    } catch (e) {
      logError('Failed to end session', e);
    } finally {
      _currentSessionId = null;
      _sessionStartTime = null;
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      _sessionSub?.cancel();
      _sessionSub = null;
      _userSub?.cancel();
      _userSub = null;
    }
  }

  /// Sends a periodic lightweight ping to the active session document
  Future<void> _pingSession() async {
    if (uid == null || _currentSessionId == null) return;

    try {
      final duration = DateTime.now().difference(_sessionStartTime!).inSeconds;

      // RTDB-only ping for active session detection
      try {
        final settingsUrl = await _getRTDBUrl('sessions/$_currentSessionId');
        if (settingsUrl != null) {
          await http.patch(
            settingsUrl,
            body: jsonEncode({
              'last_ping_at': {'.sv': 'timestamp'},
              'duration_seconds': duration,
            }),
          );
        }
      } catch (e) {
        debugPrint('[Tracking] Failed to ping RTDB session: $e');
      }

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

  /// Write general app logs to RTDB via REST API
  Future<void> logEvent(String eventName, [Map<String, dynamic>? data]) async {
    if (uid == null) return;

    try {
      final url = await _getRTDBUrl('logs');
      if (url == null) return;

      await http.post(
        url,
        body: jsonEncode({
          'event': eventName,
          'data': data ?? {},
          'timestamp': {'.sv': 'timestamp'},
          'sessionId': _currentSessionId,
        }),
      );
      debugPrint('[Tracking] Logged event to RTDB: $eventName');
    } catch (e) {
      debugPrint('[Tracking] Error logging event to RTDB: $e');
    }
  }

  /// Log an error to RTDB via REST API
  Future<void> logError(String message, [Object? error]) async {
    if (uid == null) return;

    final errorStr = error?.toString() ?? '';
    if (message.contains('setState() called after dispose()') ||
        errorStr.contains('setState() called after dispose()')) {
      return;
    }

    try {
      final url = await _getRTDBUrl('error_logs');
      if (url == null) return;

      await http.post(
        url,
        body: jsonEncode({
          'message': message,
          'error': errorStr,
          'timestamp': {'.sv': 'timestamp'},
          'sessionId': _currentSessionId,
        }),
      );
      debugPrint('[Tracking] Logged error to RTDB: $message');
    } catch (e) {
      debugPrint('[Tracking] Failed to log error to RTDB: $e');
    }
  }

  /// Push high-frequency Live Caption data to RTDB via REST API
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
      final url = await _getRTDBUrl('captions');
      if (url == null) return;

      await http.post(
        url,
        body: jsonEncode({
          'originalText': originalText,
          'translatedText': translatedText,
          'sourceLang': sourceLang,
          'targetLang': targetLang,
          'translationModel': translationModel,
          'isFinal': isFinal,
          'timestamp': {'.sv': 'timestamp'},
          'sessionId': _currentSessionId ?? 'unknown',
        }),
      );
    } catch (e) {
      debugPrint('[Tracking] Error pushing live caption to RTDB: $e');
    }
  }

  /// Log AI model translation usage stats to RTDB via REST API
  Future<void> logModelUsage(Map<String, dynamic> stats) async {
    if (uid == null) return;

    final engine = stats['engine'] as String? ?? 'unknown';
    final totalTokens = (stats['total_tokens'] as num?)?.toInt() ?? 0;
    final latencyMs = (stats['latency_ms'] as num?)?.toInt() ?? 0;
    final inputChars = (stats['input_chars'] as num?)?.toInt() ?? 0;
    final outputChars = (stats['output_chars'] as num?)?.toInt() ?? 0;

    try {
      // 1. Individual usage log entry
      final usageUrl = await _getRTDBUrl('model_usage');
      if (usageUrl != null) {
        await http.post(
          usageUrl,
          body: jsonEncode({
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
            'timestamp': {'.sv': 'timestamp'},
          }),
        );
      }

      // 2. Per-engine running totals — RTDB atomic increments via REST
      final statsUrl = await _getRTDBUrl('model_stats/$engine');
      if (statsUrl != null) {
        await http.patch(
          statsUrl,
          body: jsonEncode({
            'engine': engine,
            'total_calls': {
              '.sv': {'increment': 1},
            },
            'total_tokens': {
              '.sv': {'increment': totalTokens},
            },
            'total_latency_ms': {
              '.sv': {'increment': latencyMs},
            },
            'total_input_chars': {
              '.sv': {'increment': inputChars},
            },
            'total_output_chars': {
              '.sv': {'increment': outputChars},
            },
            'last_used': {'.sv': 'timestamp'},
          }),
        );
      }

      // 3. Overall Daily Token Usage Update in RTDB
      final now = DateTime.now();
      // Pad month and day to ensure strictly YYYY-MM-DD
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final dailyUsageUrl = await _getRTDBUrl('daily_usage/$todayStr');
      if (dailyUsageUrl != null && totalTokens > 0) {
        await http.patch(
          dailyUsageUrl,
          body: jsonEncode({
            'tokens': {
              '.sv': {'increment': totalTokens},
            },
            'last_updated': {'.sv': 'timestamp'},
          }),
        );
      }

      // 4. Per-Day, Per-Model Tokens Update in RTDB
      final dailyModelUsageUrl = await _getRTDBUrl(
        'daily_usage/$todayStr/models/$engine',
      );
      if (dailyModelUsageUrl != null) {
        await http.patch(
          dailyModelUsageUrl,
          body: jsonEncode({
            'tokens': {
              '.sv': {'increment': totalTokens},
            },
            'calls': {
              '.sv': {'increment': 1},
            },
            'last_updated': {'.sv': 'timestamp'},
          }),
        );
      }

      // 5. Application Errors / API Failures Update in RTDB
      if (stats['error'] != null) {
        final dailyErrorUrl = await _getRTDBUrl(
          'daily_usage/$todayStr/errors/$engine',
        );
        if (dailyErrorUrl != null) {
          await http.patch(
            dailyErrorUrl,
            body: jsonEncode({
              'failed_calls': {
                '.sv': {'increment': 1},
              },
              'last_error': stats['error'],
              'last_error_time': {'.sv': 'timestamp'},
            }),
          );
        }
      }

      debugPrint(
        '[Tracking] Logged model usage to RTDB: $engine (tokens: $totalTokens)',
      );
    } catch (e) {
      debugPrint('[Tracking] Failed to log model usage to RTDB: $e');
    }
  }
}

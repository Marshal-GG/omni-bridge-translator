import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:firebase_core/firebase_core.dart';
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

  static final String _appName = kDebugMode ? 'OmniBridge-Debug' : 'OmniBridge-Release';
  FirebaseApp get _app => Firebase.app(_appName);
  FirebaseAuth get _auth => FirebaseAuth.instanceFor(app: _app);
  FirebaseFirestore get _firestore => FirebaseFirestore.instanceFor(app: _app);

  String? _currentSessionId;
  DateTime? _sessionStartTime;
  Timer? _heartbeatTimer;
  StreamSubscription<DocumentSnapshot>? _sessionSub;
  StreamSubscription<DocumentSnapshot>? _userSub;

  http.Client get _httpClient => _clientInstance ??= http.Client();
  http.Client? _clientInstance;

  // Buffer for aggregating usage stats to reduce RTDB writes
  final Map<String, dynamic> _usageBuffer = {};
  Timer? _usageFlushTimer;

  // Sync control for high-frequency captions
  bool _isSyncingInterim = false;
  Map<String, dynamic>? _pendingInterim;
  int _lastCaptionTimestamp = 0;

  final String _rtdbBaseUrl =
      'https://omni-bridge-ai-translator-default-rtdb.firebaseio.com';

  /// Check if a session is currently active
  bool get hasActiveSession => _currentSessionId != null;

  /// Get current user ID
  String? get uid => _auth.currentUser?.uid;

  /// Helper to get authenticated RTDB URL
  Future<Uri?> _getRTDBUrl(String path) async {
    final user = _auth.currentUser;
    if (user == null || uid == null) return null;

    final idToken = await user.getIdToken();
    return Uri.parse('$_rtdbBaseUrl/users/$uid/$path.json?auth=$idToken');
  }

  /// Wraps an RTDB HTTP request with retry logic for transient network errors.
  Future<http.Response?> _wrapRTDBRequest(
    Future<http.Response> Function() request, {
    int maxRetries = 3,
    String? context,
  }) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        final response = await request().timeout(const Duration(seconds: 5));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        } else {
          debugPrint(
            '[Tracking] RTDB Request ($context) failed with status: ${response.statusCode}',
          );
          return response; // Return even on 4xx/5xx to handle specifically if needed
        }
      } catch (e) {
        attempts++;
        final isLastAttempt = attempts >= maxRetries;
        final isTransient = e is HandshakeException ||
            e is SocketException ||
            e is http.ClientException ||
            e is TimeoutException;

        if (isTransient && !isLastAttempt) {
          final delay = Duration(milliseconds: 500 * attempts);
          debugPrint(
            '[Tracking] RTDB Request ($context) transient error: $e. Retrying in ${delay.inMilliseconds}ms... (Attempt $attempts)',
          );
          await Future.delayed(delay);
          continue;
        }

        debugPrint('[Tracking] RTDB Request ($context) fatal error: $e');
        if (isLastAttempt) return null;
      }
    }
    return null;
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
      sessionRef = _firestore
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
      sessionRef = _firestore
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
    _userSub = _firestore
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
        await _wrapRTDBRequest(
          () => _httpClient.patch(
            settingsUrl,
            body: jsonEncode({
              'started_at': {'.sv': 'timestamp'},
            }),
          ),
          context: 'startSession',
        );
      }
    } catch (e) {
      debugPrint('[Tracking] Failed to sync session start to RTDB: $e');
    }
  }

  void _handleRemoteLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_session_id_$uid');

    // Reset forceLogout to false so re-enabling the account doesn't immediately
    // re-trigger another logout on next login. Done client-side since no Cloud Functions.
    try {
      if (uid != null) {
        // Reset global flag
        await _firestore.collection('users').doc(uid).update({
          'forceLogout': false,
        });
        // Reset per-session flag if we know the session ID
        if (_currentSessionId != null) {
          await _firestore
              .collection('users')
              .doc(uid)
              .collection('sessions')
              .doc(_currentSessionId)
              .update({'forceLogout': false});
        }
      }
    } catch (e) {
      debugPrint('[Tracking] Failed to reset forceLogout: $e');
    }

    // Auth state listener handles the rest
    await _auth.signOut();

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

      final sessionRef = _firestore
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
          await _wrapRTDBRequest(
            () => _httpClient.patch(
              settingsUrl,
              body: jsonEncode({
                'ended_at': {'.sv': 'timestamp'},
                'duration_seconds': duration,
              }),
            ),
            context: 'endSession',
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
      _usageFlushTimer?.cancel(); // Cancel any pending flush
      _usageBuffer.clear(); // Clear any buffered data
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
          await _wrapRTDBRequest(
            () => _httpClient.patch(
              settingsUrl,
              body: jsonEncode({
                'last_ping_at': {'.sv': 'timestamp'},
                'duration_seconds': duration,
              }),
            ),
            context: 'pingSession',
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
      await _firestore
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
      final doc = await _firestore
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

      await _wrapRTDBRequest(
        () => _httpClient.post(
          url,
          body: jsonEncode({
            'event': eventName,
            'data': data ?? {},
            'timestamp': {'.sv': 'timestamp'},
            'sessionId': _currentSessionId,
          }),
        ),
        context: 'logEvent: $eventName',
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

      await _wrapRTDBRequest(
        () => _httpClient.post(
          url,
          body: jsonEncode({
            'message': message,
            'error': errorStr,
            'timestamp': {'.sv': 'timestamp'},
            'sessionId': _currentSessionId,
          }),
        ),
        context: 'logError',
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

    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      if (isFinal) {
        // 1. Permanent Log (Append)
        final url = await _getRTDBUrl('captions');
        if (url != null) {
          await _wrapRTDBRequest(
            () => _httpClient.post(
              url,
              body: jsonEncode({
                'originalText': originalText,
                'translatedText': translatedText,
                'sourceLang': sourceLang,
                'targetLang': targetLang,
                'translationModel': translationModel,
                'isFinal': true,
                'timestamp': {'.sv': 'timestamp'},
                'sessionId': _currentSessionId ?? 'unknown',
              }),
            ),
            context: 'syncLiveCaption:Final',
          );
        }
        // 2. Clear interim node
        final interimUrl = await _getRTDBUrl('current_caption');
        if (interimUrl != null) {
          await _httpClient.delete(interimUrl);
        }
        // 3. Flush buffered usage stats on final segment
        await _flushUsage();

        // Reset interim sync state on final
        _lastCaptionTimestamp = now;
        _pendingInterim = null;
      } else {
        // Drop if this is older than what we've already handled (unlikely with 1 worker but safe)
        if (now < _lastCaptionTimestamp) return;

        // Prepare the data
        final data = {
          'originalText': originalText,
          'translatedText': translatedText,
          'sourceLang': sourceLang,
          'targetLang': targetLang,
          'translationModel': translationModel,
          'isFinal': false,
          'timestamp': {'.sv': 'timestamp'},
          'sessionId': _currentSessionId ?? 'unknown',
        };

        if (_isSyncingInterim) {
          // just update the pending buffer; the in-flight request will pick up the latest on completion
          _pendingInterim = data;
          return;
        }

        await _syncInterimSequentially(data);
      }
    } catch (e) {
      debugPrint('[Tracking] Error pushing live caption to RTDB: $e');
    }
  }

  /// Ensures only one 'current_caption' write is in flight at a time.
  Future<void> _syncInterimSequentially(Map<String, dynamic> data) async {
    _isSyncingInterim = true;
    _pendingInterim = null;

    try {
      final url = await _getRTDBUrl('current_caption');
      if (url != null) {
        await _wrapRTDBRequest(
          () => _httpClient.put(
            url, // Use PUT for the whole node to be cleaner
            body: jsonEncode(data),
          ),
          context: 'syncLiveCaption:Interim',
          maxRetries: 0,
        );
      }
    } finally {
      _isSyncingInterim = false;
      // If a new update arrived while we were writing, sync it now
      if (_pendingInterim != null) {
        final nextData = _pendingInterim!;
        _pendingInterim = null;
        _syncInterimSequentially(nextData);
      }
    }
  }

  /// Buffers usage stats and aggregates them to reduce HTTP calls.
  void logModelUsage(Map<String, dynamic> stats) {
    try {
      final engine = stats['engine'] as String? ?? 'unknown';
      final inputTokens = (stats['input_tokens'] as num?)?.toInt() ?? 0;
      final outputTokens = (stats['output_tokens'] as num?)?.toInt() ?? 0;
      final latencyMs = (stats['latency_ms'] as num?)?.toInt() ?? 0;

      // Accumulate in buffer
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

      // Periodic flush or wait for isFinal
      _usageFlushTimer?.cancel();
      _usageFlushTimer = Timer(const Duration(seconds: 3), () => _flushUsage());

      debugPrint(
        '[Tracking] Buffered model usage: $engine (+$inputTokens/+$outputTokens tokens)',
      );
    } catch (e) {
      debugPrint('[Tracking] Error buffering model usage: $e');
    }
  }

  /// Flushes all buffered usage stats to RTDB in a single multi-path PATCH.
  Future<void> _flushUsage() async {
    if (_usageBuffer.isEmpty) return;
    _usageFlushTimer?.cancel();

    final Map<String, dynamic> bufferCopy = Map.from(_usageBuffer);
    _usageBuffer.clear();

    final user = _auth.currentUser;
    if (user == null || uid == null) return;

    try {
      final idToken = await user.getIdToken();
      final url = Uri.parse('$_rtdbBaseUrl/users/$uid.json?auth=$idToken');

      final Map<String, dynamic> updates = {};
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      int totalDailyTokens = 0;

      for (final entry in bufferCopy.entries) {
        final engine = entry.key;
        final data = entry.value;

        // 1. Stats update (Increment)
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

        // 2. Daily total update
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

        // 3. Error tracking
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

      // 4. Update aggregates (Lifetime & Monthly) - Consolidated here for atomicity
      if (totalDailyTokens > 0) {
        updates['usage/totals/lifetime'] = {
          '.sv': {'increment': totalDailyTokens}
        };
        updates['usage/totals/calendar_monthly'] = {
          '.sv': {'increment': totalDailyTokens}
        };
        updates['usage/totals/subscription_monthly'] = {
          '.sv': {'increment': totalDailyTokens}
        };
        updates['usage/totals/weekly'] = {
          '.sv': {'increment': totalDailyTokens}
        };
      }

      if (updates.isNotEmpty) {
        await _wrapRTDBRequest(
          () => _httpClient.patch(url, body: jsonEncode(updates)),
          context: 'flushUsage (Multi-Path)',
        );
        debugPrint(
          '[Tracking] Flushed aggregated usage stats to RTDB (+$totalDailyTokens tokens).',
        );
      }
    } catch (e) {
      debugPrint('[Tracking] Failed to log model usage to RTDB: $e');
    }
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _sessionSub?.cancel();
    _userSub?.cancel();
    _httpClient.close();
  }
}

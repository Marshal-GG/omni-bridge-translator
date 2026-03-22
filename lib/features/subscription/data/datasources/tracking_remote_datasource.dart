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
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:omni_bridge/core/navigation/global_navigator.dart';
import 'package:omni_bridge/features/subscription/data/datasources/subscription_remote_datasource.dart';

class TrackingRemoteDataSource {
  TrackingRemoteDataSource._();
  static final TrackingRemoteDataSource instance = TrackingRemoteDataSource._();

  static final String _appName = kDebugMode
      ? 'OmniBridge-Debug'
      : 'OmniBridge-Release';
  FirebaseApp get _app => Firebase.app(_appName);
  FirebaseAuth get _auth => FirebaseAuth.instanceFor(app: _app);
  FirebaseFirestore get _firestore => FirebaseFirestore.instanceFor(app: _app);

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String get _sessionKeyPrefix => kDebugMode ? 'debug_' : 'release_';
  String get _googleCredentialsStorageKey =>
      '${_sessionKeyPrefix}google_translation_credentials_json';

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

  static const String _rtdbBaseUrl =
      'https://omni-bridge-ai-translator-default-rtdb.firebaseio.com';

  /// Check if a session is currently active
  bool get hasActiveSession => _currentSessionId != null;

  /// Get current user ID
  String? get uid => _auth.currentUser?.uid;

  Future<Uri?> _getRTDBUrl(String path) async {
    final user = _auth.currentUser;
    if (user == null || uid == null) return null;
    final idToken = await user.getIdToken();
    return Uri.parse('$_rtdbBaseUrl/users/$uid/$path.json?auth=$idToken');
  }

  Future<http.Response?> _rtdbRequest(
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
        }
        return response;
      } catch (e) {
        attempts++;
        final isTransient =
            e is HandshakeException ||
            e is SocketException ||
            e is http.ClientException ||
            e is TimeoutException;
        if (isTransient && attempts < maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * attempts));
          continue;
        }
        debugPrint('[Tracking] RTDB ($context) error: $e');
        return null;
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
      info['wifi_bssid'] = await net.getWifiBSSID() ?? 'N/A';
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
      debugPrint('[Tracking] Cannot start session: UID is null.');
      return;
    }

    if (_currentSessionId != null) {
      debugPrint('[Tracking] Session $_currentSessionId already running.');
      return;
    }

    final secureKey = '${_sessionKeyPrefix}current_session_id_$uid';
    String? cachedSessionId = await _secureStorage.read(key: secureKey);

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
      await _secureStorage.write(
        key: '${_sessionKeyPrefix}current_session_id_$uid',
        value: _currentSessionId!,
      );
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
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _pingSession();
    });

    _sessionSub?.cancel();
    _sessionSub = sessionRef?.snapshots().listen((snapshot) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (snapshot.exists) {
          final data = snapshot.data();
          if (data is Map<String, dynamic> && data['forceLogout'] == true) {
            debugPrint(
              '[Tracking] Remote forceLogout for session $_currentSessionId',
            );
            _handleRemoteLogout();
          }
        }
      });
    });

    _userSub?.cancel();
    _userSub = _firestore.collection('users').doc(uid).snapshots().listen((
      snapshot,
    ) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (snapshot.exists) {
          final data = snapshot.data();
          if (data is Map<String, dynamic> && data['forceLogout'] == true) {
            debugPrint('[Tracking] Remote forceLogout for user $uid');
            _handleRemoteLogout();
          }
        }
      });
    });

    try {
      final url = await _getRTDBUrl('sessions/$_currentSessionId');
      if (url != null) {
        await _rtdbRequest(
          () => _httpClient.patch(
            url,
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

    unawaited(_cleanupOldCaptions());
    unawaited(_cleanupOldDailyUsage());
    unawaited(_cleanupOldSessions());
  }

  void _handleRemoteLogout() async {
    await _secureStorage.delete(
      key: '${_sessionKeyPrefix}current_session_id_$uid',
    );
    try {
      if (uid != null) {
        await _firestore.collection('users').doc(uid).update({
          'forceLogout': false,
        });
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
    await _auth.signOut();
    await GlobalNavigator.pushNamedAndRemoveUntil('/splash', (route) => false);
  }

  /// End an app session
  Future<void> endSession() async {
    if (uid == null || _currentSessionId == null) {
      debugPrint('[Tracking] Cannot end session: UID or SessionID is null.');
      return;
    }

    try {
      await _secureStorage.delete(
        key: '${_sessionKeyPrefix}current_session_id_$uid',
      );

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
        final url = await _getRTDBUrl('sessions/$_currentSessionId');
        if (url != null) {
          await _rtdbRequest(
            () => _httpClient.patch(
              url,
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
      _usageFlushTimer?.cancel();
      _usageBuffer.clear();
    }
  }

  Future<void> _pingSession() async {
    if (uid == null || _currentSessionId == null) return;
    try {
      final duration = DateTime.now().difference(_sessionStartTime!).inSeconds;
      final url = await _getRTDBUrl('sessions/$_currentSessionId');
      if (url != null) {
        await _rtdbRequest(
          () => _httpClient.patch(
            url,
            body: jsonEncode({
              'last_ping_at': {'.sv': 'timestamp'},
              'duration_seconds': duration,
            }),
          ),
          context: 'pingSession',
        );
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
      debugPrint('[Tracking] Attempting to sync settings for UID: $uid');
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('app_preferences')
          .set({
            ...settingsData,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      debugPrint('[Tracking] User settings successfully synced to Firestore.');
    } catch (e) {
      debugPrint('[Tracking] Critical error syncing user settings: $e');
      logError('Failed to sync user settings', e);
    }
  }

  /// Fetches the Google Cloud service account credentials JSON string.
  /// Checks flutter_secure_storage first, then falls back to Firestore
  /// system/translation_config → googleCredentialsJson field.
  /// Pass [forceRefresh: true] to bypass the cache (e.g. after credential rotation).
  Future<String> getGoogleCredentials({bool forceRefresh = false}) async {
    try {
      if (!forceRefresh) {
        final cached = await _secureStorage.read(
          key: _googleCredentialsStorageKey,
        );
        if (cached != null && cached.isNotEmpty) return cached;
      }

      final doc = await _firestore
          .collection('system')
          .doc('translation_config')
          .get();
      final credentialsJson =
          doc.data()?['googleCredentialsJson'] as String? ?? '';
      if (credentialsJson.isEmpty) return '';

      await _secureStorage.write(
        key: _googleCredentialsStorageKey,
        value: credentialsJson,
      );
      return credentialsJson;
    } catch (e) {
      debugPrint('[Tracking] Failed to fetch Google credentials: $e');
      return '';
    }
  }

  /// Get current Translation Settings from Firestore
  Future<Map<String, dynamic>?> getSettings() async {
    if (uid == null) {
      debugPrint('[Tracking] Cannot fetch settings: UID is null.');
      return null;
    }
    try {
      debugPrint('[Tracking] Fetching settings for UID: $uid');
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('app_preferences')
          .get();
      if (doc.exists) {
        debugPrint(
          '[Tracking] Successfully fetched user settings from Firestore.',
        );
        return doc.data();
      } else {
        debugPrint('[Tracking] No settings found in Firestore for UID: $uid');
      }
    } catch (e) {
      debugPrint('[Tracking] Critical error fetching user settings: $e');
      logError('Failed to fetch user settings', e);
    }
    return null;
  }

  /// Log a general app event (console only — RTDB logs path removed).
  Future<void> logEvent(String eventName, [Map<String, dynamic>? data]) async {
    debugPrint('[Tracking] Event: $eventName${data != null ? ' $data' : ''}');
  }

  /// Log an error (console only — RTDB error_logs path removed).
  Future<void> logError(String message, [Object? error]) async {
    final errorStr = error?.toString() ?? '';
    if (message.contains('setState() called after dispose()') ||
        errorStr.contains('setState() called after dispose()')) {
      return;
    }
    debugPrint(
      '[Tracking] Error: $message${errorStr.isNotEmpty ? ' — $errorStr' : ''}',
    );
  }

  /// Push high-frequency Live Caption data to RTDB
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
          await _rtdbRequest(
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

        _lastCaptionTimestamp = now;
        _pendingInterim = null;
      } else {
        if (now < _lastCaptionTimestamp) return;

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
          _pendingInterim = data;
          return;
        }

        await _syncInterimSequentially(data);
      }
    } catch (e) {
      debugPrint('[Tracking] Error pushing live caption to RTDB: $e');
    }
  }

  Future<void> _syncInterimSequentially(Map<String, dynamic> data) async {
    _isSyncingInterim = true;
    _pendingInterim = null;

    try {
      final url = await _getRTDBUrl('current_caption');
      if (url != null) {
        await _rtdbRequest(
          () => _httpClient.put(url, body: jsonEncode(data)),
          context: 'syncLiveCaption:Interim',
          maxRetries: 1,
        );
      }
    } finally {
      _isSyncingInterim = false;
      if (_pendingInterim != null) {
        final nextData = _pendingInterim!;
        _pendingInterim = null;
        _syncInterimSequentially(nextData);
      }
    }
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
          '.sv': {'increment': data['calls'] > 0 ? (data['latency_ms'] / data['calls']).toInt() : 0}, // Simplification
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
        await _rtdbRequest(
          () => _httpClient.patch(url, body: jsonEncode(updates)),
          context: 'flushUsage',
        );
        debugPrint(
          '[Tracking] Flushed usage stats to RTDB (+$totalDailyTokens tokens).',
        );
      }
    } catch (e) {
      debugPrint('[Tracking] Failed to flush usage to RTDB: $e');
    }
  }

  /// Deletes RTDB captions older than the tier's retention window.
  /// Called fire-and-forget on session start. Reads retention config from
  /// SubscriptionRemoteDataSource (sourced from system/monetization in Firestore).
  Future<void> _cleanupOldCaptions() async {
    final userUid = uid;
    if (userUid == null) return;

    try {
      final retentionDays = SubscriptionRemoteDataSource.instance.captionRetentionDays;
      if (retentionDays <= 0) return; // free tier — nothing stored to clean

      final cutoffMs = DateTime.now()
          .subtract(Duration(days: retentionDays))
          .millisecondsSinceEpoch;

      final url = await _getRTDBUrl('captions');
      if (url == null) return;

      final response = await _rtdbRequest(
        () => _httpClient.get(url),
        context: 'cleanupOldCaptions:fetch',
        maxRetries: 1,
      );
      if (response == null || response.statusCode != 200) return;

      final raw = jsonDecode(response.body);
      if (raw == null || raw is! Map) return;
      final data = raw as Map<String, dynamic>;

      final Map<String, dynamic> deletions = {};
      for (final entry in data.entries) {
        final ts = (entry.value as Map<String, dynamic>?)?['timestamp'];
        if (ts is num && ts < cutoffMs) {
          deletions[entry.key] = null; // null = delete in RTDB
        }
      }

      if (deletions.isEmpty) return;

      final user = _auth.currentUser;
      if (user == null) return;
      final idToken = await user.getIdToken();
      final deleteUrl = Uri.parse(
        '$_rtdbBaseUrl/users/$userUid/captions.json?auth=$idToken',
      );

      await _rtdbRequest(
        () => _httpClient.patch(deleteUrl, body: jsonEncode(deletions)),
        context: 'cleanupOldCaptions:delete',
        maxRetries: 1,
      );
      debugPrint(
        '[Tracking] Cleaned up ${deletions.length} old captions (>${retentionDays}d).',
      );
    } catch (e) {
      debugPrint('[Tracking] Caption cleanup failed: $e');
    }
  }

  /// Deletes RTDB daily_usage entries older than 90 days on session start.
  /// Uses shallow=true to fetch only keys, avoiding downloading all usage data.
  Future<void> _cleanupOldDailyUsage() async {
    final userUid = uid;
    if (userUid == null) return;

    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 90));
      final user = _auth.currentUser;
      if (user == null) return;
      final idToken = await user.getIdToken();

      final url = Uri.parse(
        '$_rtdbBaseUrl/users/$userUid/daily_usage.json?shallow=true&auth=$idToken',
      );
      final response = await _rtdbRequest(
        () => _httpClient.get(url),
        context: 'cleanupOldDailyUsage:fetch',
        maxRetries: 1,
      );
      if (response == null || response.statusCode != 200) return;

      final raw = jsonDecode(response.body);
      if (raw == null || raw is! Map) return;

      final Map<String, dynamic> deletions = {};
      for (final key in raw.keys) {
        try {
          final date = DateTime.parse(key.toString());
          if (date.isBefore(cutoffDate)) {
            deletions[key.toString()] = null;
          }
        } catch (_) {
          // invalid date key, ignore
        }
      }

      if (deletions.isEmpty) return;

      final deleteUrl = Uri.parse(
        '$_rtdbBaseUrl/users/$userUid/daily_usage.json?auth=$idToken',
      );
      await _rtdbRequest(
        () => _httpClient.patch(deleteUrl, body: jsonEncode(deletions)),
        context: 'cleanupOldDailyUsage:delete',
        maxRetries: 1,
      );
      debugPrint(
        '[Tracking] Cleaned up ${deletions.length} old daily_usage entries (>=90d).',
      );
    } catch (e) {
      debugPrint('[Tracking] Daily usage cleanup failed: $e');
    }
  }

  Future<void> _cleanupOldSessions() async {
    final userUid = uid;
    if (userUid == null) return;
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 90));
      final snapshots = await _firestore
          .collection('users')
          .doc(userUid)
          .collection('sessions')
          .where('startTime', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      if (snapshots.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (var doc in snapshots.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      debugPrint('[Tracking] Cleaned up ${snapshots.docs.length} old sessions from Firestore.');
    } catch (e) {
      debugPrint('[Tracking] Session cleanup failed: $e');
    }
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _sessionSub?.cancel();
    _userSub?.cancel();
    _httpClient.close();
  }
}

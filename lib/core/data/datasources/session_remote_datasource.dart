import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:omni_bridge/core/navigation/global_navigator.dart';
import 'package:omni_bridge/core/network/rtdb_client.dart';
import 'package:omni_bridge/core/utils/device_info_util.dart';

class SessionRemoteDataSource {
  SessionRemoteDataSource._();
  static final SessionRemoteDataSource instance = SessionRemoteDataSource._();

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

  String? _currentSessionId;
  DateTime? _sessionStartTime;
  Timer? _heartbeatTimer;
  StreamSubscription<DocumentSnapshot>? _sessionSub;
  StreamSubscription<DocumentSnapshot>? _userSub;

  final RTDBClient _rtdbClient = RTDBClient.instance;

  /// Check if a session is currently active
  bool get hasActiveSession => _currentSessionId != null;

  /// Get current session ID
  String? get currentSessionId => _currentSessionId;

  /// Get current user ID
  String? get uid => _auth.currentUser?.uid;

  /// Start an app session
  Future<void> startSession() async {
    if (uid == null) {
      debugPrint('[SessionRemoteDataSource] Cannot start session: UID is null.');
      return;
    }

    if (_currentSessionId != null) {
      debugPrint('[SessionRemoteDataSource] Session $_currentSessionId already running.');
      return;
    }

    final secureKey = '${_sessionKeyPrefix}current_session_id_$uid';
    String? cachedSessionId = await _secureStorage.read(key: secureKey);

    _sessionStartTime = DateTime.now();
    final deviceInfo = await DeviceInfoUtil.getDeviceInfo();

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
              '[SessionRemoteDataSource] Resumed existing session $_currentSessionId',
            );
          }
        }
      } catch (e) {
        debugPrint('[SessionRemoteDataSource] Failed to check existing session: $e');
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
        debugPrint('[SessionRemoteDataSource] Session $_currentSessionId started');
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
              '[SessionRemoteDataSource] Remote forceLogout for session $_currentSessionId',
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
            debugPrint('[SessionRemoteDataSource] Remote forceLogout for user $uid');
            _handleRemoteLogout();
          }
        }
      });
    });

    try {
      final url = await _rtdbClient.getRTDBUrl('sessions/$_currentSessionId');
      if (url != null) {
        await _rtdbClient.request(
          (client) => client.patch(
            url,
            body: jsonEncode({
              'started_at': {'.sv': 'timestamp'},
            }),
          ),
          context: 'startSession',
        );
      }
    } catch (e) {
      debugPrint('[SessionRemoteDataSource] Failed to sync session start to RTDB: $e');
    }
  }

  void _handleRemoteLogout() async {
    final userUid = uid;
    if (userUid != null) {
      await _secureStorage.delete(
        key: '${_sessionKeyPrefix}current_session_id_$userUid',
      );

      try {
        await _firestore.collection('users').doc(userUid).update({
          'forceLogout': false,
        });
        if (_currentSessionId != null) {
          await _firestore
              .collection('users')
              .doc(userUid)
              .collection('sessions')
              .doc(_currentSessionId)
              .update({'forceLogout': false});
        }
      } catch (e) {
        debugPrint('[SessionRemoteDataSource] Failed to reset forceLogout: $e');
      }
    }
    
    await _auth.signOut();
    await GlobalNavigator.pushNamedAndRemoveUntil('/splash', (route) => false);
  }

  /// Resets the singleton state. Called on logout to prevent session leakage.
  Future<void> reset() async {
    _currentSessionId = null;
    _sessionStartTime = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _sessionSub?.cancel();
    _sessionSub = null;
    _userSub?.cancel();
    _userSub = null;
    
    debugPrint('[SessionRemoteDataSource] state reset');
  }

  /// End an app session and clear user-specific local state.
  Future<void> endSession() async {
    final userUid = uid;
    if (userUid == null || _currentSessionId == null) {
      debugPrint('[SessionRemoteDataSource] Cannot end session: UID or SessionID is null.');
      await reset();
      return;
    }

    try {
      await _secureStorage.delete(
        key: '${_sessionKeyPrefix}current_session_id_$userUid',
      );

      final sessionRef = _firestore
          .collection('users')
          .doc(userUid)
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
        final url = await _rtdbClient.getRTDBUrl('sessions/$_currentSessionId');
        if (url != null) {
          await _rtdbClient.request(
            (client) => client.patch(
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
        debugPrint('[SessionRemoteDataSource] Failed to sync session end to RTDB: $e');
      }

      debugPrint('[SessionRemoteDataSource] Session $_currentSessionId ended');
    } catch (e) {
      logError('Failed to end session', e);
    } finally {
      await reset();
    }
  }

  Future<void> _pingSession() async {
    if (uid == null || _currentSessionId == null) return;
    try {
      final diff = _sessionStartTime != null ? DateTime.now().difference(_sessionStartTime!) : Duration.zero;
      final duration = diff.inSeconds;
      final url = await _rtdbClient.getRTDBUrl('sessions/$_currentSessionId');
      if (url != null) {
        await _rtdbClient.request(
          (client) => client.patch(
            url,
            body: jsonEncode({
              'last_ping_at': {'.sv': 'timestamp'},
              'duration_seconds': duration,
            }),
          ),
          context: 'pingSession',
        );
      }
      debugPrint('[SessionRemoteDataSource] Heartbeat ping sent.');
    } catch (e) {
      debugPrint('[SessionRemoteDataSource] Failed to send heartbeat ping: $e');
    }
  }

  /// Log an error
  Future<void> logError(String message, [Object? error]) async {
    final errorStr = error?.toString() ?? '';
    if (message.contains('setState() called after dispose()') ||
        errorStr.contains('setState() called after dispose()')) {
      return;
    }
    debugPrint(
      '[SessionRemoteDataSource] Error: $message${errorStr.isNotEmpty ? ' — $errorStr' : ''}',
    );
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _sessionSub?.cancel();
    _userSub?.cancel();
  }
}

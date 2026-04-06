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
import 'package:omni_bridge/core/utils/app_logger.dart';
import 'package:omni_bridge/core/constants/firebase_paths.dart';
import 'package:omni_bridge/core/data/interfaces/resettable.dart';

class SessionRemoteDataSource implements IResettable {
  SessionRemoteDataSource._();
  static final SessionRemoteDataSource instance = SessionRemoteDataSource._();

  static const String _tag = 'SessionRemoteDataSource';

  FirebaseApp get _app => Firebase.app(RTDBClient.appName);
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
      AppLogger.w('Cannot start session: UID is null.', tag: _tag);
      return;
    }

    if (_currentSessionId != null) {
      AppLogger.i('Session $_currentSessionId already running.', tag: _tag);
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
          .collection(FirebasePaths.users)
          .doc(uid)
          .collection(FirebasePaths.sessions)
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
            AppLogger.i(
              'Resumed existing session $_currentSessionId',
              tag: _tag,
            );
          }
        }
      } catch (e) {
        AppLogger.e('Failed to check existing session', error: e, tag: _tag);
      }
    }

    if (isNewSession) {
      sessionRef = _firestore
          .collection(FirebasePaths.users)
          .doc(uid)
          .collection(FirebasePaths.sessions)
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
        AppLogger.i('Session $_currentSessionId started', tag: _tag);
      } catch (e) {
        AppLogger.e('Failed to start session', error: e, tag: _tag);
      }
    }

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _pingSession();
    });

    await _sessionSub?.cancel();
    _sessionSub = sessionRef?.snapshots().listen((snapshot) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (snapshot.exists) {
          final data = snapshot.data();
          if (data is Map<String, dynamic> && data['forceLogout'] == true) {
            AppLogger.w(
              'Remote forceLogout for session $_currentSessionId',
              tag: _tag,
            );
            _handleRemoteLogout();
          }
        }
      });
    });

    await _userSub?.cancel();
    _userSub = _firestore
        .collection(FirebasePaths.users)
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (snapshot.exists) {
              final data = snapshot.data();
              if (data is Map<String, dynamic> && data['forceLogout'] == true) {
                AppLogger.w('Remote forceLogout for user $uid', tag: _tag);
                _handleRemoteLogout();
              }
            }
          });
        });

    try {
      final url = await _rtdbClient.getRTDBUrl(
        '${FirebasePaths.activeSessions}/$_currentSessionId',
      );
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
      AppLogger.e('Failed to sync session start to RTDB', error: e, tag: _tag);
    }
  }

  /// Called by [AuthRemoteDataSource] during init to wire up the full logout
  /// flow. This avoids a circular import: AuthRemoteDataSource → Session, but
  /// Session cannot import Auth. The callback is set once and never changes.
  Future<void> Function()? _onForceLogout;

  void setForceLogoutHandler(Future<void> Function() handler) {
    _onForceLogout = handler;
  }

  Future<void> _handleRemoteLogout() async {
    final userUid = uid;
    if (userUid != null) {
      // Reset forceLogout flag before signing out so listeners don't re-fire
      try {
        await _firestore.collection(FirebasePaths.users).doc(userUid).update({
          'forceLogout': false,
        });
        if (_currentSessionId != null) {
          await _firestore
              .collection(FirebasePaths.users)
              .doc(userUid)
              .collection(FirebasePaths.sessions)
              .doc(_currentSessionId)
              .update({'forceLogout': false});
        }
      } catch (e) {
        AppLogger.e('Failed to reset forceLogout', error: e, tag: _tag);
      }
    }

    // Delegate to the full signOut flow (resets all IResettables, ends the
    // session in Firestore, flushes usage, navigates to /splash).
    // Falls back to a direct Firebase sign-out if the handler was never set.
    if (_onForceLogout != null) {
      await _onForceLogout!();
    } else {
      await _auth.signOut();
      await GlobalNavigator.pushNamedAndRemoveUntil('/splash', (route) => false);
    }
  }

  /// Resets the singleton state. Called on logout to prevent session leakage.
  @override
  void reset() {
    _currentSessionId = null;
    _sessionStartTime = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _sessionSub?.cancel();
    _sessionSub = null;
    _userSub?.cancel();
    _userSub = null;

    AppLogger.i('state reset', tag: _tag);
  }

  /// End an app session and clear user-specific local state.
  Future<void> endSession() async {
    final userUid = uid;
    if (userUid == null || _currentSessionId == null) {
      AppLogger.w('Cannot end session: UID or SessionID is null.', tag: _tag);
      reset();
      return;
    }

    try {
      await _secureStorage.delete(
        key: '${_sessionKeyPrefix}current_session_id_$userUid',
      );

      final sessionRef = _firestore
          .collection(FirebasePaths.users)
          .doc(userUid)
          .collection(FirebasePaths.sessions)
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
        final url = await _rtdbClient.getRTDBUrl(
          '${FirebasePaths.activeSessions}/$_currentSessionId',
        );
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
        AppLogger.e('Failed to sync session end to RTDB', error: e, tag: _tag);
      }

      AppLogger.i('Session $_currentSessionId ended', tag: _tag);
    } catch (e) {
      AppLogger.e('Failed to end session', error: e, tag: _tag);
    } finally {
      reset();
    }
  }

  Future<void> _pingSession() async {
    if (uid == null || _currentSessionId == null) return;
    try {
      final diff = _sessionStartTime != null
          ? DateTime.now().difference(_sessionStartTime!)
          : Duration.zero;
      final duration = diff.inSeconds;
      final url = await _rtdbClient.getRTDBUrl(
        '${FirebasePaths.activeSessions}/$_currentSessionId',
      );
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
      AppLogger.d('Heartbeat ping sent.', tag: _tag);
    } catch (e) {
      AppLogger.e('Failed to send heartbeat ping', error: e, tag: _tag);
    }
  }

  /// Log an error
  void logError(String message, [Object? error]) {
    final errorStr = error?.toString() ?? '';
    if (message.contains('setState() called after dispose()') ||
        errorStr.contains('setState() called after dispose()')) {
      return;
    }
    AppLogger.e(
      '$message${errorStr.isNotEmpty ? ' — $errorStr' : ''}',
      tag: _tag,
    );
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _sessionSub?.cancel();
    _userSub?.cancel();
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TrackingService {
  TrackingService._();
  static final TrackingService instance = TrackingService._();

  String? _currentSessionId;
  DateTime? _sessionStartTime;
  Timer? _heartbeatTimer;

  /// Get current user ID
  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  /// Start an app session
  Future<void> startSession() async {
    if (uid == null) {
      debugPrint(
        '[Tracking] Cannot start session: UID is null. User not signed in.',
      );
      return;
    }

    _sessionStartTime = DateTime.now();

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
        'deviceInfo':
            'Windows Desktop', // Extend as needed with device_info_plus
        'isEnded': false,
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
    String text,
    String sourceLang,
    String targetLang,
    bool isFinal,
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
          'text': text,
          'sourceLang': sourceLang,
          'targetLang': targetLang,
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
}

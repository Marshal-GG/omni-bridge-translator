import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:omni_bridge/core/constants/firebase_paths.dart';
import 'package:omni_bridge/core/data/interfaces/resettable.dart';
import 'package:omni_bridge/core/utils/app_logger.dart';

class RTDBClient implements IResettable {
  RTDBClient._();
  static final RTDBClient instance = RTDBClient._();

  static const String appName = kDebugMode
      ? 'OmniBridge-Debug'
      : 'OmniBridge-Release';

  FirebaseApp get _app => Firebase.app(appName);
  FirebaseAuth get _auth => FirebaseAuth.instanceFor(app: _app);

  http.Client get _httpClient => _clientInstance ??= http.Client();
  http.Client? _clientInstance;

  static const String rtdbBaseUrl = FirebasePaths.rtdbBaseUrl;

  String? get uid => _auth.currentUser?.uid;

  /// Gets the full RTDB URL for the given user-scoped path.
  Future<Uri?> getRTDBUrl(String path) async {
    final user = _auth.currentUser;
    if (user == null || uid == null) return null;
    final idToken = await user.getIdToken();
    return Uri.parse('$rtdbBaseUrl/users/$uid/$path.json?auth=$idToken');
  }

  /// Gets a full RTDB URL for a non-user-scoped path (advanced).
  Future<Uri?> getAbsoluteUrl(String path) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final idToken = await user.getIdToken();
    return Uri.parse('$rtdbBaseUrl/$path.json?auth=$idToken');
  }

  /// Makes an RTDB request with transient error retries.
  ///
  /// On a 401 response the Firebase ID token is force-refreshed so the
  /// next call (which re-fetches the URL via [getRTDBUrl]/[getAbsoluteUrl])
  /// will carry a fresh token. The current request is returned as-is; for
  /// background writes (usage metrics, session tracking) this is acceptable.
  Future<http.Response?> request(
    Future<http.Response> Function(http.Client client) requestFunc, {
    int maxRetries = 3,
    String? context,
  }) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        final response = await requestFunc(
          _httpClient,
        ).timeout(const Duration(seconds: 5));
        if (response.statusCode == 401 || response.statusCode == 403) {
          AppLogger.w(
            '[RTDBClient] ${response.statusCode} on $context — forcing token refresh.',
            tag: 'RTDB',
          );
          await _auth.currentUser?.getIdToken(true);
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
        AppLogger.e(
          '[RTDBClient] RTDB ($context) error: $e',
          tag: 'RTDB',
          error: e,
        );
        return null;
      }
    }
    return null;
  }

  @override
  void reset() {
    dispose();
    AppLogger.i('[RTDBClient] Resetting HTTP client.', tag: 'RTDB');
  }

  void dispose() {
    _clientInstance?.close();
    _clientInstance = null;
  }
}

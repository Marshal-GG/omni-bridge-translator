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

  /// Makes an RTDB request with transient error retries and a single
  /// automatic 401/403 retry.
  ///
  /// [makeRequest] receives the resolved [Uri] each time it is called.
  /// [buildUrl] is called once up-front and again after a 401/403 so the
  /// fresh token baked into the URL query string is picked up automatically.
  Future<http.Response?> request(
    Future<http.Response> Function(http.Client client, Uri url) makeRequest,
    Future<Uri?> Function() buildUrl, {
    int maxRetries = 3,
    String? context,
  }) async {
    Uri? url = await buildUrl();
    if (url == null) return null;

    bool tokenRefreshed = false;
    int transientAttempts = 0;

    while (true) {
      try {
        final response = await makeRequest(_httpClient, url!)
            .timeout(const Duration(seconds: 5));

        if ((response.statusCode == 401 || response.statusCode == 403) &&
            !tokenRefreshed) {
          AppLogger.w(
            '[RTDBClient] ${response.statusCode} on $context — forcing token refresh and retrying.',
            tag: 'RTDB',
          );
          await _auth.currentUser?.getIdToken(true);
          final refreshedUrl = await buildUrl();
          if (refreshedUrl == null) return response;
          url = refreshedUrl;
          tokenRefreshed = true;
          continue;
        }

        return response;
      } catch (e) {
        transientAttempts++;
        final isTransient =
            e is HandshakeException ||
            e is SocketException ||
            e is http.ClientException ||
            e is TimeoutException;
        if (isTransient && transientAttempts < maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * transientAttempts));
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

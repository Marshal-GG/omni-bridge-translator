import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class RTDBClient {
  RTDBClient._();
  static final RTDBClient instance = RTDBClient._();

  static final String _appName = kDebugMode
      ? 'OmniBridge-Debug'
      : 'OmniBridge-Release';
  FirebaseApp get _app => Firebase.app(_appName);
  FirebaseAuth get _auth => FirebaseAuth.instanceFor(app: _app);

  http.Client get _httpClient => _clientInstance ??= http.Client();
  http.Client? _clientInstance;

  static const String _rtdbBaseUrl =
      'https://omni-bridge-ai-translator-default-rtdb.firebaseio.com';

  String? get uid => _auth.currentUser?.uid;

  /// Gets the full RTDB URL for the given user-scoped path.
  Future<Uri?> getRTDBUrl(String path) async {
    final user = _auth.currentUser;
    if (user == null || uid == null) return null;
    final idToken = await user.getIdToken();
    return Uri.parse('$_rtdbBaseUrl/users/$uid/$path.json?auth=$idToken');
  }

  /// Gets a full RTDB URL for a non-user-scoped path (advanced).
  Future<Uri?> getAbsoluteUrl(String path) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final idToken = await user.getIdToken();
    return Uri.parse('$_rtdbBaseUrl/$path.json?auth=$idToken');
  }

  /// Makes an RTDB request with transient error retries.
  Future<http.Response?> request(
    Future<http.Response> Function(http.Client client) requestFunc, {
    int maxRetries = 3,
    String? context,
  }) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        final response = await requestFunc(_httpClient).timeout(const Duration(seconds: 5));
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
        debugPrint('[RTDBClient] RTDB ($context) error: $e');
        return null;
      }
    }
    return null;
  }

  void dispose() {
    _httpClient.close();
  }
}

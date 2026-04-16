import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:omni_bridge/core/config/app_config.dart';
import 'package:omni_bridge/core/constants/auth_html_constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:omni_bridge/core/network/rtdb_client.dart';
import 'package:omni_bridge/core/data/datasources/session_remote_datasource.dart';
import 'package:omni_bridge/core/data/datasources/usage_metrics_remote_datasource.dart';
import 'package:omni_bridge/core/navigation/global_navigator.dart';
import 'package:omni_bridge/core/di/di.dart';
import 'package:omni_bridge/core/utils/app_logger.dart';
import 'package:omni_bridge/core/constants/firebase_paths.dart';
import 'package:omni_bridge/core/data/interfaces/resettable.dart';

class AuthRemoteDataSource implements IResettable {
  AuthRemoteDataSource._();
  static final AuthRemoteDataSource instance = AuthRemoteDataSource._();

  static const String _tag = 'Auth';

  FirebaseApp get _app => Firebase.app(RTDBClient.appName);
  FirebaseAuth get _auth => FirebaseAuth.instanceFor(app: _app);
  FirebaseFirestore get _firestore => FirebaseFirestore.instanceFor(app: _app);

  // Public getters used by UI components (e.g., AdminPanel)
  FirebaseAuth get auth => _auth;
  FirebaseFirestore get firestore => _firestore;

  /// Exposes the current signed-in user (or null if not signed in).
  ValueNotifier<User?> currentUser = ValueNotifier(null);

  StreamSubscription<User?>? _authStateSub;

  late final GoogleSignIn _googleSignIn;
  Completer<String?>? _authCodeCompleter;

  void init() {
    // Immediate initialization of currentUser for route determination
    currentUser.value = _auth.currentUser;

    // Wire the force-logout callback so SessionRemoteDataSource can trigger
    // the full signOut flow without a circular import.
    SessionRemoteDataSource.instance.setForceLogoutHandler(signOut);

    // We delay the full initialization until after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  void _initialize() {
    const redirectUrl = ''; // Default empty
    final customHtml = customAuthSuccessHtml.replaceFirst(
      '{{REDIRECT_URL}}',
      redirectUrl,
    );

    _googleSignIn = GoogleSignIn(
      params: GoogleSignInParams(
        clientId: AppConfig.googleClientId,
        clientSecret:
            '', // Provide empty if not using Web Application client type
        scopes: ['email', 'profile'],
        customPostAuthPage: customHtml,
      ),
    );

    // Listen to Firebase auth state changes automatically
    _authStateSub = _auth.authStateChanges().listen((user) async {
      // Ensure state updates happen on the UI thread to avoid Windows threading errors
      SchedulerBinding.instance.addPostFrameCallback((_) async {
        currentUser.value = user;
        if (user != null) {
          if (!SessionRemoteDataSource.instance.hasActiveSession) {
            await SessionRemoteDataSource.instance.startSession();
            await UsageMetricsRemoteDataSource.instance.logEvent(
              'App Opened (Restored Session)',
            );
          }
        } else {
          if (SessionRemoteDataSource.instance.hasActiveSession) {
            await SessionRemoteDataSource.instance.endSession();
          }
        }
      });
    });

    // Attempt silent sign-in on init
    _googleSignIn.silentSignIn().then((credentials) async {
      if (credentials != null && _auth.currentUser == null) {
        final credential = GoogleAuthProvider.credential(
          accessToken: credentials.accessToken,
          idToken: credentials.idToken,
        );
        await _auth.signInWithCredential(credential);
        await UsageMetricsRemoteDataSource.instance.logEvent(
          'Silent Sign In via Init',
        );
      }
    });
  }

  /// Resets the datasource state (clears listeners, completers).
  @override
  void reset() {
    _authCodeCompleter?.complete(null);
    _authCodeCompleter = null;
    AppLogger.i('auth state reset', tag: _tag);
  }

  void dispose() {
    _authStateSub?.cancel();
  }

  bool get isLoggedIn => currentUser.value != null;

  /// Handles the incoming authentication redirect from the custom protocol.
  void handleAuthRedirect(Uri uri) {
    AppLogger.d('handleAuthRedirect: $uri', tag: _tag);
    // The code might be in queryParameters or fragmented depending on the browser behavior
    String? code = uri.queryParameters['code'];

    // Fallback: search raw query string if queryParameters failed (sometimes happens with single slash)
    if (code == null && uri.hasQuery) {
      final matches = RegExp(r'code=([^&]+)').firstMatch(uri.toString());
      code = matches?.group(1);
    }

    if (code != null) {
      AppLogger.i(
        'Extracted code: ${code.substring(0, code.length > 5 ? 5 : code.length)}...',
        tag: _tag,
      );
      if (_authCodeCompleter != null && !_authCodeCompleter!.isCompleted) {
        _authCodeCompleter!.complete(code);
      }
    } else {
      AppLogger.w('No code found in URI: $uri', tag: _tag);
    }
  }

  /// Google Sign-In via system browser for Windows.
  /// Tries silent sign-in (cached credentials) first to avoid the browser
  /// OAuth flow, which can hang when the local HTTP callback server is blocked.
  Future<User?> signInWithGoogle() async {
    try {
      AppLogger.i('Step 1: Trying silentSignIn...', tag: _tag);
      GoogleSignInCredentials? result = await _googleSignIn.silentSignIn();

      if (result != null) {
        AppLogger.i('Got cached credentials.', tag: _tag);
      } else {
        AppLogger.i(
          'No cache, performing manual OAuth flow with custom redirect...',
          tag: _tag,
        );

        final clientId = AppConfig.googleClientId;
        _authCodeCompleter = Completer<String?>();

        final scopes = ['email', 'profile'].join(' ');

        // If it's an iOS client ID, we use the custom scheme redirect
        // format: com.googleusercontent.apps.XXX:/oauth2redirect
        final protocol = kDebugMode ? 'omni-bridge-debug' : 'omni-bridge';
        String redirectUri = '$protocol://auth';
        if (clientId.isNotEmpty &&
            clientId.contains('.apps.googleusercontent.com')) {
          final scheme = clientId.split('.').reversed.join('.');
          // Using :/ instead of :// to match Google's strict requirements for desktop/iOS redirects
          redirectUri = '$scheme:/oauth2redirect';
        }

        final authUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
          'client_id': clientId,
          'redirect_uri': redirectUri,
          'response_type': 'code',
          'scope': scopes,
        });

        AppLogger.i('Launching Auth URL: $authUri', tag: _tag);

        if (await canLaunchUrl(authUri)) {
          await launchUrl(authUri, mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not launch $authUri';
        }

        final code = await _authCodeCompleter!.future;
        _authCodeCompleter = null;

        if (code == null) {
          AppLogger.w('Auth failed or canceled.', tag: _tag);
          return null;
        }

        AppLogger.i('Exchange code for tokens...', tag: _tag);
        // Note: For Windows desktop apps with custom schemes, we use the loopback server or
        // a manual exchange. In this case, we use the google_sign_in_all_platforms' internal
        // machinery if possible, but since we are doing it manually, we need to hit the token endpoint.
        // However, we can also use the desktop_webview_auth for the exchange part if it supports it,
        // but it's simpler to just do the HTTP POST.

        // Actually, we can use the result of the exchange to sign into Firebase.
        // For simplicity and dependency management, I'll attempt to use the existing _googleSignIn
        // if it can handle the code, but it usually doesn't expose that.

        // Let's use a standard token exchange.
        final response = await http.post(
          Uri.parse('https://oauth2.googleapis.com/token'),
          body: {
            'code': code,
            'client_id': clientId,
            'redirect_uri': redirectUri,
            'grant_type': 'authorization_code',
          },
        );

        if (response.statusCode != 200) {
          AppLogger.e('Token exchange failed: ${response.body}', tag: _tag);
          return null;
        }

        final tokenData = jsonDecode(response.body);
        result = GoogleSignInCredentials(
          accessToken: tokenData['access_token'],
          idToken: tokenData['id_token'],
        );
      }

      AppLogger.i('Step 4: Signing into Firebase...', tag: _tag);
      final credential = GoogleAuthProvider.credential(
        accessToken: result.accessToken,
        idToken: result.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await _saveUserToFirestore(userCredential.user!);
        await UsageMetricsRemoteDataSource.instance.logEvent(
          'Sign In With Google',
        );
      }
      AppLogger.i('Step 5: Done → ${userCredential.user?.email}', tag: _tag);
      return userCredential.user;
    } catch (e) {
      AppLogger.e('Google Sign-In EXCEPTION', error: e, tag: _tag);
      return null;
    }
  }

  Future<User?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (userCredential.user != null) {
      await _saveUserToFirestore(userCredential.user!);
      await UsageMetricsRemoteDataSource.instance.logEvent(
        'Sign In With Email/Password',
      );
    }
    return userCredential.user;
  }

  Future<User?> registerWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (userCredential.user != null) {
      await _saveUserToFirestore(userCredential.user!);
      await UsageMetricsRemoteDataSource.instance.logEvent(
        'Registered With Email/Password',
      );
    }
    return userCredential.user;
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
    await UsageMetricsRemoteDataSource.instance.logEvent(
      'Password Reset Requested',
    );
  }

  Future<void> updateDisplayName(String newName) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.updateDisplayName(newName);
      await user.reload();
      final updatedUser = _auth.currentUser;
      currentUser.value = updatedUser;

      // Sync the updated name to the users collection
      if (updatedUser != null) {
        await _saveUserToFirestore(updatedUser);
      }

      await UsageMetricsRemoteDataSource.instance.logEvent(
        'Display Name Updated',
      );
    }
  }

  Future<void> signOut() async {
    // Phase 1: Logging & Active Session Termination
    await UsageMetricsRemoteDataSource.instance.logEvent('User Signed Out');
    try {
      await SessionRemoteDataSource.instance.endSession();
    } catch (e) {
      AppLogger.e('Failed to end session during logout', error: e, tag: _tag);
    }

    // Phase 2: Comprehensive Reset of all registered IResettable Components
    final resettables = [
      'auth_reset',
      'sub_reset',
      'session_reset',
      'metrics_reset',
      'usage_reset',
      'settings_reset',
      'transcription_reset',
      'rtdb_reset',
      'history_reset',
      'support_local_reset',
      'translation_reset',
      'live_caption_reset',
    ];

    for (final name in resettables) {
      try {
        if (sl.isRegistered<IResettable>(instanceName: name)) {
          sl.get<IResettable>(instanceName: name).reset();
        }
      } catch (e) {
        AppLogger.e('Error resetting $name during logout', error: e, tag: _tag);
      }
    }

    // Phase 3: Firebase SignOut
    await _auth.signOut();

    // Ensure we redirect to splash on manual sign out as well
    await GlobalNavigator.pushNamedAndRemoveUntil('/splash', (route) => false);
  }

  /// Returns true if [email] is in the admin whitelist at system/admins.
  Future<bool> checkAdminStatus(String email) async {
    try {
      final doc = await _firestore.doc(FirebasePaths.adminEmails).get();
      final emails = List<String>.from(doc.data()?['emails'] ?? []);
      return emails.contains(email);
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveUserToFirestore(User user) async {
    try {
      final userRef = _firestore.collection(FirebasePaths.users).doc(user.uid);
      final docSnapshot = await userRef.get();

      final Map<String, dynamic> data = {
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'photoURL': user.photoURL,
        'phoneNumber': user.phoneNumber,
        'lastSignInTime': user.metadata.lastSignInTime?.toIso8601String(),
        'creationTime': user.metadata.creationTime?.toIso8601String(),
      };

      if (!docSnapshot.exists) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }

      data['lastLoginAt'] = FieldValue.serverTimestamp();

      await userRef.set(data, SetOptions(merge: true));
      AppLogger.i('Saved user data to Firestore', tag: _tag);
    } catch (e) {
      AppLogger.e('Error saving user to Firestore', error: e, tag: _tag);
    }
  }
}

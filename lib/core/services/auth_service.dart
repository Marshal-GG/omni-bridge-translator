import 'dart:async';
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
import 'tracking_service.dart';
import '../navigation/global_navigator.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  /// Exposes the current signed-in user (or null if not signed in).
  ValueNotifier<User?> currentUser = ValueNotifier(null);

  StreamSubscription<User?>? _authStateSub;

  late final GoogleSignIn _googleSignIn;
  Completer<String?>? _authCodeCompleter;

  void init() {
    // Immediate initialization of currentUser for route determination
    currentUser.value = FirebaseAuth.instance.currentUser;

    // We delay the full initialization until after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  void _initialize() {
    // Inject the redirect URL if provided in the environment variables
    // final redirectUrl = dotenv.env['AUTH_SUCCESS_REDIRECT_URL'] ?? '';
    const redirectUrl = ''; // Default empty if not using environment overrides
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
    _authStateSub = FirebaseAuth.instance.authStateChanges().listen((
      user,
    ) async {
      // Ensure state updates happen on the UI thread to avoid Windows threading errors
      SchedulerBinding.instance.addPostFrameCallback((_) async {
        currentUser.value = user;
        if (user != null) {
          if (!TrackingService.instance.hasActiveSession) {
            await TrackingService.instance.startSession();
            await TrackingService.instance.logEvent(
              'App Opened (Restored Session)',
            );
          }
        } else {
          if (TrackingService.instance.hasActiveSession) {
            await TrackingService.instance.endSession();
          }
        }
      });
    });

    // Attempt silent sign-in on init
    _googleSignIn.silentSignIn().then((credentials) async {
      if (credentials != null && FirebaseAuth.instance.currentUser == null) {
        final credential = GoogleAuthProvider.credential(
          accessToken: credentials.accessToken,
          idToken: credentials.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
        await TrackingService.instance.logEvent('Silent Sign In via Init');
      }
    });
  }

  void dispose() {
    _authStateSub?.cancel();
  }

  bool get isLoggedIn => currentUser.value != null;

  /// Handles the incoming authentication redirect from the custom protocol.
  void handleAuthRedirect(Uri uri) {
    debugPrint('[Auth] handleAuthRedirect: $uri');
    // The code might be in queryParameters or fragmented depending on the browser behavior
    String? code = uri.queryParameters['code'];

    // Fallback: search raw query string if queryParameters failed (sometimes happens with single slash)
    if (code == null && uri.hasQuery) {
      final matches = RegExp(r'code=([^&]+)').firstMatch(uri.toString());
      code = matches?.group(1);
    }

    if (code != null) {
      debugPrint(
        '[Auth] Extracted code: ${code.substring(0, code.length > 5 ? 5 : code.length)}...',
      );
      if (_authCodeCompleter != null && !_authCodeCompleter!.isCompleted) {
        _authCodeCompleter!.complete(code);
      }
    } else {
      debugPrint('[Auth] No code found in URI: $uri');
    }
  }

  /// Google Sign-In via system browser for Windows.
  /// Tries silent sign-in (cached credentials) first to avoid the browser
  /// OAuth flow, which can hang when the local HTTP callback server is blocked.
  Future<User?> signInWithGoogle() async {
    try {
      debugPrint('[Auth] Step 1: Trying silentSignIn...');
      GoogleSignInCredentials? result = await _googleSignIn.silentSignIn();

      if (result != null) {
        debugPrint('[Auth] Got cached credentials.');
      } else {
        debugPrint(
          '[Auth] No cache, performing manual OAuth flow with custom redirect...',
        );

        final clientId = AppConfig.googleClientId;
        _authCodeCompleter = Completer<String?>();

        final scopes = ['email', 'profile'].join(' ');

        // If it's an iOS client ID, we use the custom scheme redirect
        // format: com.googleusercontent.apps.XXX:/oauth2redirect
        String redirectUri = 'omni-bridge://auth';
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

        debugPrint('[Auth] Launching Auth URL: $authUri');

        if (await canLaunchUrl(authUri)) {
          await launchUrl(authUri, mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not launch $authUri';
        }

        final code = await _authCodeCompleter!.future;
        _authCodeCompleter = null;

        if (code == null) {
          debugPrint('[Auth] Auth failed or canceled.');
          return null;
        }

        debugPrint('[Auth] Exchange code for tokens...');
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
          debugPrint('[Auth] Token exchange failed: ${response.body}');
          return null;
        }

        final tokenData = jsonDecode(response.body);
        result = GoogleSignInCredentials(
          accessToken: tokenData['access_token'],
          idToken: tokenData['id_token'],
        );
      }

      debugPrint('[Auth] Step 4: Signing into Firebase...');
      final credential = GoogleAuthProvider.credential(
        accessToken: result.accessToken,
        idToken: result.idToken,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      if (userCredential.user != null) {
        await _saveUserToFirestore(userCredential.user!);
        await TrackingService.instance.logEvent('Sign In With Google');
      }
      debugPrint('[Auth] Step 5: Done → ${userCredential.user?.email}');
      return userCredential.user;
    } catch (e) {
      debugPrint('[Auth] Google Sign-In EXCEPTION: $e');
      return null;
    }
  }

  Future<User?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final userCredential = await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: password);
    if (userCredential.user != null) {
      await _saveUserToFirestore(userCredential.user!);
      await TrackingService.instance.logEvent('Sign In With Email/Password');
    }
    return userCredential.user;
  }

  Future<User?> registerWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final userCredential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);
    if (userCredential.user != null) {
      await _saveUserToFirestore(userCredential.user!);
      await TrackingService.instance.logEvent('Registered With Email/Password');
    }
    return userCredential.user;
  }

  Future<void> sendPasswordReset(String email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    await TrackingService.instance.logEvent('Password Reset Requested');
  }


  Future<void> updateDisplayName(String newName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.updateDisplayName(newName);
      await user.reload();
      final updatedUser = FirebaseAuth.instance.currentUser;
      currentUser.value = updatedUser;

      // Sync the updated name to the users collection
      if (updatedUser != null) {
        await _saveUserToFirestore(updatedUser);
      }

      await TrackingService.instance.logEvent('Display Name Updated');
    }
  }

  Future<void> signOut() async {
    // Do NOT call _googleSignIn.signOut() — it corrupts the package's
    // internal HTTP server state, causing the next signIn() to hang.
    await TrackingService.instance.logEvent('User Signed Out');
    await TrackingService.instance.endSession();
    await FirebaseAuth.instance.signOut();

    // Ensure we redirect to splash on manual sign out as well
    await GlobalNavigator.pushNamedAndRemoveUntil('/splash', (route) => false);
  }


  Future<void> _saveUserToFirestore(User user) async {
    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
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
      debugPrint('[Auth] Saved user data to Firestore');
    } catch (e) {
      debugPrint('[Auth] Error saving user to Firestore: $e');
    }
  }
}

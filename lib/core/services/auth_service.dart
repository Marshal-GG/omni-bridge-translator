import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:omni_bridge/core/utils/auth_html_constants.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  /// Exposes the current signed-in user (or null if not signed in).
  ValueNotifier<User?> currentUser = ValueNotifier(null);
  StreamSubscription<User?>? _authStateSub;

  late final GoogleSignIn _googleSignIn;

  void init() {
    _googleSignIn = GoogleSignIn(
      params: GoogleSignInParams(
        clientId: dotenv.env['GOOGLE_CLIENT_ID'] ?? '',
        clientSecret:
            '', // Provide empty if not using Web Application client type
        scopes: ['email', 'profile'],
        customPostAuthPage: customAuthSuccessHtml,
      ),
    );

    // Listen to Firebase auth state changes automatically
    _authStateSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      currentUser.value = user;
    });

    // Attempt silent sign-in on init
    _googleSignIn.silentSignIn().then((credentials) async {
      if (credentials != null && FirebaseAuth.instance.currentUser == null) {
        final credential = GoogleAuthProvider.credential(
          accessToken: credentials.accessToken,
          idToken: credentials.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
    });
  }

  void dispose() {
    _authStateSub?.cancel();
  }

  bool get isLoggedIn => currentUser.value != null;

  /// Google Sign-In via system browser for Windows.
  /// Tries silent sign-in (cached credentials) first to avoid the browser
  /// OAuth flow, which can hang when the local HTTP callback server is blocked.
  Future<User?> signInWithGoogle() async {
    try {
      debugPrint('[Auth] Step 1: Trying silentSignIn...');
      GoogleSignInCredentials? result = await _googleSignIn.silentSignIn();
      debugPrint(
        '[Auth] Step 2: silentSignIn → ${result == null ? 'no cache, opening browser' : 'got cached credentials'}',
      );

      // If no cached credentials, fall back to the full browser flow
      result ??= await _googleSignIn.signIn();
      debugPrint(
        '[Auth] Step 3: signIn result → ${result == null ? 'NULL (canceled)' : 'credentials received'}',
      );

      if (result == null) {
        debugPrint('[Auth] Google Auth canceled or failed.');
        return null;
      }

      debugPrint('[Auth] Step 4: Signing into Firebase...');
      final credential = GoogleAuthProvider.credential(
        accessToken: result.accessToken,
        idToken: result.idToken,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      debugPrint('[Auth] Step 5: Done → ${userCredential.user?.email}');
      return userCredential.user;
    } catch (e) {
      debugPrint('[Auth] Google Sign-In EXCEPTION: $e');
      return null;
    }
  }

  /// Sign in with Email and Password
  Future<User?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final userCredential = await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: password);
    return userCredential.user;
  }

  /// Register with Email and Password
  Future<User?> registerWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final userCredential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);
    return userCredential.user;
  }

  /// Dev bypass: signs in a user anonymously
  Future<User?> bypassForDev() async {
    try {
      final userCredential = await FirebaseAuth.instance.signInAnonymously();
      return userCredential.user;
    } catch (e) {
      debugPrint('[Auth] Dev Bypass failed: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    // Do NOT call _googleSignIn.signOut() — it corrupts the package's
    // internal HTTP server state, causing the next signIn() to hang.
    await FirebaseAuth.instance.signOut();
  }
}

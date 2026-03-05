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

  /// Google Sign-In via system browser for Windows
  Future<User?> signInWithGoogle() async {
    try {
      final result = await _googleSignIn.signIn();
      if (result == null) {
        debugPrint('[Auth] Google Auth canceled or failed.');
        return null;
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: result.accessToken,
        idToken: result.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      return userCredential.user;
    } catch (e) {
      debugPrint('[Auth] Google Sign-In failed: $e');
      return null;
    }
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
    await _googleSignIn.signOut();
    await FirebaseAuth.instance.signOut();
  }
}

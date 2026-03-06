import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:omni_bridge/core/utils/auth_html_constants.dart';
import 'tracking_service.dart';

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
    _authStateSub = FirebaseAuth.instance.authStateChanges().listen((
      user,
    ) async {
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

    // Attempt silent sign-in on init
    _googleSignIn.silentSignIn().then((credentials) async {
      if (credentials != null && FirebaseAuth.instance.currentUser == null) {
        final credential = GoogleAuthProvider.credential(
          accessToken: credentials.accessToken,
          idToken: credentials.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
        await TrackingService.instance.startSession();
        await TrackingService.instance.logEvent('Silent Sign In via Init');
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
      if (userCredential.user != null) {
        await _saveUserToFirestore(userCredential.user!);
        await TrackingService.instance.startSession();
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
      await TrackingService.instance.startSession();
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
      await TrackingService.instance.startSession();
      await TrackingService.instance.logEvent('Registered With Email/Password');
    }
    return userCredential.user;
  }

  Future<User?> bypassForDev() async {
    try {
      final userCredential = await FirebaseAuth.instance.signInAnonymously();
      if (userCredential.user != null) {
        await _saveUserToFirestore(userCredential.user!);
        await TrackingService.instance.startSession();
        await TrackingService.instance.logEvent('Sign In Dev Bypass');
      }
      return userCredential.user;
    } catch (e) {
      debugPrint('[Auth] Dev Bypass failed: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    // Do NOT call _googleSignIn.signOut() — it corrupts the package's
    // internal HTTP server state, causing the next signIn() to hang.
    await TrackingService.instance.logEvent('User Signed Out');
    await TrackingService.instance.endSession();
    await FirebaseAuth.instance.signOut();
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

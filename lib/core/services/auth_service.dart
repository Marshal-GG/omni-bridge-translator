import 'dart:async';
import 'package:flutter/foundation.dart';

/// A Mock User class to replace FirebaseAuth User on Windows
/// to unblock the build while keeping the dev bypass functional.
class MockUser {
  final String uid;
  final String? email;
  final String? displayName;
  final bool isAnonymous;

  MockUser({
    required this.uid,
    this.email,
    this.displayName,
    this.isAnonymous = false,
  });
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  /// Exposes the current signed-in user (or null if not signed in).
  ValueNotifier<MockUser?> currentUser = ValueNotifier(null);

  void init() {
    // No-op for mock
  }

  void dispose() {
    // No-op for mock
  }

  bool get isLoggedIn => currentUser.value != null;

  /// Google Sign-In Mock.
  Future<MockUser?> signInWithGoogle() async {
    // Google Sign-In is unavailable on Windows without the plugin.
    // We'll treat this as a no-op or return a mock user if you want to test.
    debugPrint(
      '[Auth] Google Sign-In is currently stubbed for Windows build compatibility.',
    );
    return null;
  }

  /// Dev bypass: signs in a mock user locally.
  Future<MockUser?> bypassForDev() async {
    final mockUser = MockUser(
      uid: 'dev-user-123',
      displayName: 'Developer',
      isAnonymous: true,
    );
    currentUser.value = mockUser;
    return mockUser;
  }

  Future<void> signOut() async {
    currentUser.value = null;
  }
}

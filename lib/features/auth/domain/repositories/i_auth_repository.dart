import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:omni_bridge/core/error/failures.dart';

abstract class IAuthRepository {
  ValueListenable<User?> get currentUser;
  Stream<User?> get authStateChanges;

  Future<Either<Failure, User>> signInWithGoogle();
  Future<Either<Failure, User>> signInWithEmailAndPassword(
    String email,
    String password,
  );
  Future<Either<Failure, User>> registerWithEmailAndPassword(
    String email,
    String password,
  );
  Future<Either<Failure, void>> sendPasswordReset(String email);
  Future<void> signOut();
  Future<bool> isAdmin(String email);
}

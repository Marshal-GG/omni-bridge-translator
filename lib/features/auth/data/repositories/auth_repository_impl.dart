import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:omni_bridge/core/error/failures.dart';
import 'package:omni_bridge/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:omni_bridge/features/auth/domain/repositories/i_auth_repository.dart';

class AuthRepositoryImpl implements IAuthRepository {
  final AuthRemoteDataSource _authRemoteDataSource;

  AuthRepositoryImpl(this._authRemoteDataSource);

  @override
  ValueListenable<User?> get currentUser => _authRemoteDataSource.currentUser;

  @override
  Stream<User?> get authStateChanges => _authRemoteDataSource.auth.authStateChanges();

  @override
  Future<Either<Failure, User>> signInWithGoogle() async {
    try {
      final user = await _authRemoteDataSource.signInWithGoogle();
      if (user != null) {
        return Right(user);
      } else {
        return Left(AuthFailure('Google Sign-In failed or cancelled.'));
      }
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      final user = await _authRemoteDataSource.signInWithEmailAndPassword(email, password);
      if (user != null) {
        return Right(user);
      } else {
        return Left(AuthFailure('Sign-In failed.'));
      }
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> registerWithEmailAndPassword(
      String email, String password) async {
    try {
      final user =
          await _authRemoteDataSource.registerWithEmailAndPassword(email, password);
      if (user != null) {
        return Right(user);
      } else {
        return Left(AuthFailure('Registration failed.'));
      }
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> sendPasswordReset(String email) async {
    try {
      await _authRemoteDataSource.sendPasswordReset(email);
      return const Right(null);
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  @override
  Future<void> signOut() async {
    await _authRemoteDataSource.signOut();
  }
}




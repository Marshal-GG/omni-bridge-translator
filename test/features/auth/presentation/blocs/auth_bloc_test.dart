import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:omni_bridge/features/auth/presentation/blocs/auth_bloc.dart';
import 'package:omni_bridge/features/auth/presentation/blocs/auth_event.dart';
import 'package:omni_bridge/features/auth/presentation/blocs/auth_state.dart';

import '../../../../helpers/test_mocks.dart';

import 'package:dartz/dartz.dart';
import 'package:omni_bridge/core/error/failures.dart';

class MockUser extends Mock implements User {}

void main() {
  late AuthBloc authBloc;
  late MockAuthRepository mockAuthRepository;
  late MockUser mockUser;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    authBloc = AuthBloc(authRepository: mockAuthRepository);
    mockUser = MockUser();

    // Setup mocktail fallbacks if we used complex models in 'any()' calls
    registerFallbackValue('dummy_string');
  });

  tearDown(() {
    authBloc.close();
  });

  group('AuthBloc', () {
    test('initial state should be AuthInitial', () {
      expect(authBloc.state, const AuthInitial());
    });

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] when login with email succeeds',
      build: () {
        when(
          () => mockAuthRepository.signInWithEmailAndPassword(any(), any()),
        ).thenAnswer((_) async => Right(mockUser));
        return authBloc;
      },
      act: (bloc) => bloc.add(
        const AuthLoginWithEmailPasswordEvent('test@test.com', 'password123'),
      ),
      expect: () => [const AuthLoading(), const AuthAuthenticated()],
      verify: (_) {
        verify(
          () => mockAuthRepository.signInWithEmailAndPassword(
            'test@test.com',
            'password123',
          ),
        ).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] when login fails with generic exception',
      build: () {
        when(
          () => mockAuthRepository.signInWithEmailAndPassword(any(), any()),
        ).thenThrow(Exception('Generic error'));
        return authBloc;
      },
      act: (bloc) => bloc.add(
        const AuthLoginWithEmailPasswordEvent('test@test.com', 'password123'),
      ),
      expect: () => [
        const AuthLoading(),
        const AuthError(
          'An unexpected error occurred: Exception: Generic error',
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthUnauthenticated] on successful logout',
      build: () {
        when(() => mockAuthRepository.signOut()).thenAnswer((_) async {});
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthLogoutEvent()),
      expect: () => [const AuthLoading(), const AuthUnauthenticated()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthPasswordResetSent, AuthInitial] when password reset is successful',
      build: () {
        when(
          () => mockAuthRepository.sendPasswordReset(any()),
        ).thenAnswer((_) async => Right<Failure, void>(null));
        return authBloc;
      },
      act: (bloc) =>
          bloc.add(const AuthSendPasswordResetEvent('test@test.com')),
      expect: () => [
        const AuthLoading(),
        const AuthPasswordResetSent('test@test.com'),
        const AuthInitial(),
      ],
    );
  });
}

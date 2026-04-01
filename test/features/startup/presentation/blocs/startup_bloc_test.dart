import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:omni_bridge/features/startup/presentation/blocs/startup_bloc.dart';
import 'package:omni_bridge/features/startup/presentation/blocs/startup_event.dart';
import 'package:omni_bridge/features/startup/presentation/blocs/startup_state.dart';
import 'package:omni_bridge/features/auth/domain/repositories/i_auth_repository.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

class MockUser extends Mock implements User {}

void main() {
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
  });

  test('initial state is StartupInitial', () {
    when(
      () => mockAuthRepository.currentUser,
    ).thenReturn(ValueNotifier<User?>(null));
    final bloc = StartupBloc(authRepository: mockAuthRepository);
    expect(bloc.state, const StartupInitial());
    bloc.close();
  });

  blocTest<StartupBloc, StartupState>(
    'emits [StartupLoading, StartupNavigateToHome] when user is logged in',
    build: () {
      final mockUser = MockUser();
      when(
        () => mockAuthRepository.currentUser,
      ).thenReturn(ValueNotifier<User?>(mockUser));
      return StartupBloc(authRepository: mockAuthRepository);
    },
    act: (bloc) => bloc.add(const StartupInitializeEvent()),
    wait: const Duration(milliseconds: 2200),
    expect: () => [const StartupLoading(), const StartupNavigateToHome()],
  );

  blocTest<StartupBloc, StartupState>(
    'emits [StartupLoading, StartupNavigateToOnboarding] when user is not logged in',
    build: () {
      when(
        () => mockAuthRepository.currentUser,
      ).thenReturn(ValueNotifier<User?>(null));
      return StartupBloc(authRepository: mockAuthRepository);
    },
    act: (bloc) => bloc.add(const StartupInitializeEvent()),
    wait: const Duration(milliseconds: 2200),
    expect: () => [const StartupLoading(), const StartupNavigateToOnboarding()],
  );
}

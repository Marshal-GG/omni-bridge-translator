import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omni_bridge/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:omni_bridge/features/auth/domain/usecases/observe_auth_changes_usecase.dart';
import 'package:omni_bridge/features/subscription/domain/usecases/get_subscription_status.dart';

import 'app_shell_event.dart';
import 'app_shell_state.dart';

class AppShellBloc extends Bloc<AppShellEvent, AppShellState> {
  final ObserveAuthChangesUseCase _observeAuthChanges;
  final GetSubscriptionStatus _getSubscriptionStatus;

  StreamSubscription? _authSubscription;
  StreamSubscription? _statusSubscription;

  AppShellBloc({
    required GetCurrentUserUseCase getCurrentUser,
    required ObserveAuthChangesUseCase observeAuthChanges,
    required GetSubscriptionStatus getSubscriptionStatus,
  })  : _observeAuthChanges = observeAuthChanges,
        _getSubscriptionStatus = getSubscriptionStatus,
        super(AppShellState(
          currentUser: getCurrentUser.call().value,
          currentSubscriptionStatus: getSubscriptionStatus.current,
        )) {
    on<AppShellUserChanged>(_onUserChanged);
    on<AppShellSubscriptionStatusChanged>(_onStatusChanged);

    // Listen to changes
    _authSubscription = _observeAuthChanges.call().listen((user) {
      add(AppShellUserChanged(user));
    });

    _statusSubscription = _getSubscriptionStatus.call().listen((status) {
      add(AppShellSubscriptionStatusChanged(status));
    });
  }

  void _onUserChanged(
    AppShellUserChanged event,
    Emitter<AppShellState> emit,
  ) {
    emit(state.copyWith(currentUser: () => event.user));
  }

  void _onStatusChanged(
    AppShellSubscriptionStatusChanged event,
    Emitter<AppShellState> emit,
  ) {
    emit(state.copyWith(currentSubscriptionStatus: () => event.status));
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    _statusSubscription?.cancel();
    return super.close();
  }
}


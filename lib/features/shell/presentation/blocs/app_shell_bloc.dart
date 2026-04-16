import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:omni_bridge/core/platform/window_manager.dart';
import 'package:omni_bridge/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:omni_bridge/features/auth/domain/usecases/observe_auth_changes_usecase.dart';
import 'package:omni_bridge/features/auth/domain/usecases/check_admin_status_usecase.dart';
import 'package:omni_bridge/features/subscription/domain/usecases/get_subscription_status.dart';
import 'package:omni_bridge/core/navigation/app_router.dart';
import 'package:omni_bridge/core/navigation/route_change_notifier.dart';

import 'app_shell_event.dart';
import 'app_shell_state.dart';

class AppShellBloc extends Bloc<AppShellEvent, AppShellState>
    implements RouteChangeNotifier {
  final ObserveAuthChangesUseCase _observeAuthChanges;
  final GetSubscriptionStatus _getSubscriptionStatus;
  final CheckAdminStatusUseCase _checkAdminStatusUseCase;

  StreamSubscription? _authSubscription;
  StreamSubscription? _statusSubscription;

  AppShellBloc({
    required GetCurrentUserUseCase getCurrentUser,
    required ObserveAuthChangesUseCase observeAuthChanges,
    required GetSubscriptionStatus getSubscriptionStatus,
    required CheckAdminStatusUseCase checkAdminStatus,
  }) : _observeAuthChanges = observeAuthChanges,
       _getSubscriptionStatus = getSubscriptionStatus,
       _checkAdminStatusUseCase = checkAdminStatus,
       super(
         AppShellState(
           currentUser: getCurrentUser.call().value,
           currentSubscriptionStatus: getSubscriptionStatus.current,
         ),
       ) {
    on<AppShellUserChanged>(_onUserChanged);
    on<AppShellSubscriptionStatusChanged>(_onStatusChanged);
    on<AppShellToggleSettingsExpanded>(_onToggleSettingsExpanded);
    on<AppShellToggleSupportExpanded>(_onToggleSupportExpanded);
    on<AppShellRouteChanged>(_onRouteChanged);
    on<AppShellToggleSidebarEvent>(_onToggleSidebar);
    on<AppShellAdminStatusChanged>(_onAdminStatusChanged);

    // Listen to auth changes
    _authSubscription = _observeAuthChanges.call().listen((user) {
      add(AppShellUserChanged(user));
    });

    // Listen to subscription status changes
    _statusSubscription = _getSubscriptionStatus.call().listen((status) {
      add(AppShellSubscriptionStatusChanged(status));
    });
  }

  void _onUserChanged(AppShellUserChanged event, Emitter<AppShellState> emit) {
    emit(state.copyWith(currentUser: () => event.user, isAdmin: false));
    if (event.user != null) {
      _checkAdminStatus(event.user!);
    }
  }

  Future<void> _checkAdminStatus(User user) async {
    if (user.email == null) return;
    final isAdmin = await _checkAdminStatusUseCase.call(user.email!);
    if (!isClosed) add(AppShellAdminStatusChanged(isAdmin: isAdmin));
  }

  void _onAdminStatusChanged(
    AppShellAdminStatusChanged event,
    Emitter<AppShellState> emit,
  ) {
    emit(state.copyWith(isAdmin: event.isAdmin));
  }

  void _onStatusChanged(
    AppShellSubscriptionStatusChanged event,
    Emitter<AppShellState> emit,
  ) {
    emit(state.copyWith(currentSubscriptionStatus: () => event.status));
  }

  void _onToggleSettingsExpanded(
    AppShellToggleSettingsExpanded event,
    Emitter<AppShellState> emit,
  ) {
    if (event.isExpanded != null) {
      emit(state.copyWith(isSettingsExpanded: event.isExpanded!));
    } else {
      emit(state.copyWith(isSettingsExpanded: !state.isSettingsExpanded));
    }
  }

  void _onToggleSupportExpanded(
    AppShellToggleSupportExpanded event,
    Emitter<AppShellState> emit,
  ) {
    if (event.isExpanded != null) {
      emit(state.copyWith(isSupportExpanded: event.isExpanded!));
    } else {
      emit(state.copyWith(isSupportExpanded: !state.isSupportExpanded));
    }
  }

  void _onRouteChanged(
    AppShellRouteChanged event,
    Emitter<AppShellState> emit,
  ) {
    if (event.routeName == AppRouter.settingsOverlay) {
      emit(state.copyWith(isSettingsExpanded: true));
    } else if (event.routeName == AppRouter.support) {
      emit(state.copyWith(isSupportExpanded: true));
    }
  }

  void _onToggleSidebar(
    AppShellToggleSidebarEvent event,
    Emitter<AppShellState> emit,
  ) {
    final newExpanded = event.isExpanded ?? !state.isSidebarExpanded;

    // Adjust the OS window size to match navigation rail width changes
    toggleNavRailWindowSize(newExpanded);

    // When collapsing, close all sub-menus so they don't remain open invisibly.
    if (!newExpanded) {
      emit(
        state.copyWith(
          isSidebarExpanded: false,
          isSettingsExpanded: false,
          isSupportExpanded: false,
        ),
      );
    } else {
      emit(state.copyWith(isSidebarExpanded: true));
    }
  }

  /// Called by the navigator observer via the [RouteChangeNotifier] interface.
  @override
  void onRouteChanged(String routeName) {
    add(AppShellRouteChanged(routeName));
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    _statusSubscription?.cancel();
    return super.close();
  }
}

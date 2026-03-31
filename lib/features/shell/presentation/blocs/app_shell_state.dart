import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:omni_bridge/features/subscription/domain/entities/subscription_status.dart';

class AppShellState extends Equatable {
  final User? currentUser;
  final SubscriptionStatus? currentSubscriptionStatus;
  final bool isSettingsExpanded;
  final bool isSupportExpanded;

  const AppShellState({
    this.currentUser,
    this.currentSubscriptionStatus,
    this.isSettingsExpanded = false,
    this.isSupportExpanded = false,
  });

  AppShellState copyWith({
    User? Function()? currentUser,
    SubscriptionStatus? Function()? currentSubscriptionStatus,
    bool? isSettingsExpanded,
    bool? isSupportExpanded,
  }) {
    return AppShellState(
      currentUser: currentUser != null ? currentUser() : this.currentUser,
      currentSubscriptionStatus: currentSubscriptionStatus != null
          ? currentSubscriptionStatus()
          : this.currentSubscriptionStatus,
      isSettingsExpanded: isSettingsExpanded ?? this.isSettingsExpanded,
      isSupportExpanded: isSupportExpanded ?? this.isSupportExpanded,
    );
  }

  @override
  List<Object?> get props => [
        currentUser,
        currentSubscriptionStatus,
        isSettingsExpanded,
        isSupportExpanded,
      ];
}

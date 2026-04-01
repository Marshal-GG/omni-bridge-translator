import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';

class AppShellState extends Equatable {
  final User? currentUser;
  final QuotaStatus? currentSubscriptionStatus;
  final bool isSettingsExpanded;
  final bool isSupportExpanded;
  final bool isSidebarExpanded;

  const AppShellState({
    this.currentUser,
    this.currentSubscriptionStatus,
    this.isSettingsExpanded = false,
    this.isSupportExpanded = false,
    this.isSidebarExpanded = true,
  });

  AppShellState copyWith({
    User? Function()? currentUser,
    QuotaStatus? Function()? currentSubscriptionStatus,
    bool? isSettingsExpanded,
    bool? isSupportExpanded,
    bool? isSidebarExpanded,
  }) {
    return AppShellState(
      currentUser: currentUser != null ? currentUser() : this.currentUser,
      currentSubscriptionStatus: currentSubscriptionStatus != null
          ? currentSubscriptionStatus()
          : this.currentSubscriptionStatus,
      isSettingsExpanded: isSettingsExpanded ?? this.isSettingsExpanded,
      isSupportExpanded: isSupportExpanded ?? this.isSupportExpanded,
      isSidebarExpanded: isSidebarExpanded ?? this.isSidebarExpanded,
    );
  }

  @override
  List<Object?> get props => [
        currentUser,
        currentSubscriptionStatus,
        isSettingsExpanded,
        isSupportExpanded,
        isSidebarExpanded,
      ];
}

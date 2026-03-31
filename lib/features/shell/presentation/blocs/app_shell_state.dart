import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:omni_bridge/features/subscription/domain/entities/subscription_status.dart';

class AppShellState extends Equatable {
  final User? currentUser;
  final SubscriptionStatus? currentSubscriptionStatus;

  const AppShellState({
    this.currentUser,
    this.currentSubscriptionStatus,
  });

  AppShellState copyWith({
    User? Function()? currentUser,
    SubscriptionStatus? Function()? currentSubscriptionStatus,
  }) {
    return AppShellState(
      currentUser: currentUser != null ? currentUser() : this.currentUser,
      currentSubscriptionStatus: currentSubscriptionStatus != null
          ? currentSubscriptionStatus()
          : this.currentSubscriptionStatus,
    );
  }

  @override
  List<Object?> get props => [
        currentUser,
        currentSubscriptionStatus,
      ];
}

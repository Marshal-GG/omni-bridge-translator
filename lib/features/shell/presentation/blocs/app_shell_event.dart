import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:omni_bridge/features/subscription/domain/entities/subscription_status.dart';

abstract class AppShellEvent extends Equatable {
  const AppShellEvent();

  @override
  List<Object?> get props => [];
}

class AppShellUserChanged extends AppShellEvent {
  final User? user;

  const AppShellUserChanged(this.user);

  @override
  List<Object?> get props => [user];
}

class AppShellSubscriptionStatusChanged extends AppShellEvent {
  final SubscriptionStatus? status;

  const AppShellSubscriptionStatusChanged(this.status);

  @override
  List<Object?> get props => [status];
}

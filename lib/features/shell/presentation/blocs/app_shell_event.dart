import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';

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
  final QuotaStatus? status;

  const AppShellSubscriptionStatusChanged(this.status);

  @override
  List<Object?> get props => [status];
}

class AppShellToggleSettingsExpanded extends AppShellEvent {
  final bool? isExpanded;

  const AppShellToggleSettingsExpanded({this.isExpanded});

  @override
  List<Object?> get props => [isExpanded];
}

class AppShellToggleSupportExpanded extends AppShellEvent {
  final bool? isExpanded;

  const AppShellToggleSupportExpanded({this.isExpanded});

  @override
  List<Object?> get props => [isExpanded];
}

class AppShellRouteChanged extends AppShellEvent {
  final String routeName;

  const AppShellRouteChanged(this.routeName);

  @override
  List<Object?> get props => [routeName];
}

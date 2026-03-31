import 'package:equatable/equatable.dart';
import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';

abstract class SubscriptionEvent extends Equatable {
  const SubscriptionEvent();

  @override
  List<Object?> get props => [];
}

class SubscriptionLoaded extends SubscriptionEvent {}

class SubscriptionStatusUpdated extends SubscriptionEvent {
  final QuotaStatus status;

  const SubscriptionStatusUpdated(this.status);

  @override
  List<Object?> get props => [status];
}

class SubscriptionActivateTrial extends SubscriptionEvent {}

class SubscriptionOpenCheckout extends SubscriptionEvent {
  final String tierId;

  const SubscriptionOpenCheckout(this.tierId);

  @override
  List<Object?> get props => [tierId];
}

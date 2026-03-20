import 'package:equatable/equatable.dart';
import 'package:omni_bridge/data/models/subscription_models.dart';

abstract class SubscriptionEvent extends Equatable {
  const SubscriptionEvent();

  @override
  List<Object?> get props => [];
}

class SubscriptionLoaded extends SubscriptionEvent {}

class SubscriptionStatusUpdated extends SubscriptionEvent {
  final SubscriptionStatus status;

  const SubscriptionStatusUpdated(this.status);

  @override
  List<Object?> get props => [status];
}

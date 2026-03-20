import 'package:equatable/equatable.dart';
import 'package:omni_bridge/data/models/subscription_models.dart';

class SubscriptionState extends Equatable {
  final bool isLoading;
  final SubscriptionStatus? status;
  final List<SubscriptionPlan> plans;
  final bool trialUsed;

  const SubscriptionState({
    this.isLoading = true,
    this.status,
    this.plans = const [],
    this.trialUsed = false,
  });

  SubscriptionState copyWith({
    bool? isLoading,
    SubscriptionStatus? status,
    List<SubscriptionPlan>? plans,
    bool? trialUsed,
  }) {
    return SubscriptionState(
      isLoading: isLoading ?? this.isLoading,
      status: status ?? this.status,
      plans: plans ?? this.plans,
      trialUsed: trialUsed ?? this.trialUsed,
    );
  }

  @override
  List<Object?> get props => [isLoading, status, plans, trialUsed];
}

import 'package:equatable/equatable.dart';
import '../../domain/entities/subscription_status.dart';
import '../../domain/entities/subscription_plan.dart';

class SubscriptionState extends Equatable {
  final bool isLoading;
  final SubscriptionStatus? status;
  final List<SubscriptionPlan> plans;
  final bool trialUsed;
  final String? error;

  const SubscriptionState({
    this.isLoading = true,
    this.status,
    this.plans = const [],
    this.trialUsed = false,
    this.error,
  });

  SubscriptionState copyWith({
    bool? isLoading,
    SubscriptionStatus? status,
    List<SubscriptionPlan>? plans,
    bool? trialUsed,
    String? error,
  }) {
    return SubscriptionState(
      isLoading: isLoading ?? this.isLoading,
      status: status ?? this.status,
      plans: plans ?? this.plans,
      trialUsed: trialUsed ?? this.trialUsed,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [isLoading, status, plans, trialUsed, error];
}

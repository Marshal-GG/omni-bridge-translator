import 'package:equatable/equatable.dart';
import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';
import '../../domain/entities/subscription_plan.dart';

enum BillingCycle { monthly, yearly }

class SubscriptionState extends Equatable {
  final bool isLoading;
  final QuotaStatus? status;
  final List<SubscriptionPlan> plans;
  final bool trialUsed;
  final BillingCycle billingCycle;
  final String? error;

  const SubscriptionState({
    this.isLoading = true,
    this.status,
    this.plans = const [],
    this.trialUsed = false,
    this.billingCycle = BillingCycle.monthly,
    this.error,
  });

  SubscriptionState copyWith({
    bool? isLoading,
    QuotaStatus? status,
    List<SubscriptionPlan>? plans,
    bool? trialUsed,
    BillingCycle? billingCycle,
    String? error,
  }) {
    return SubscriptionState(
      isLoading: isLoading ?? this.isLoading,
      status: status ?? this.status,
      plans: plans ?? this.plans,
      trialUsed: trialUsed ?? this.trialUsed,
      billingCycle: billingCycle ?? this.billingCycle,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props =>
      [isLoading, status, plans, trialUsed, billingCycle, error];
}

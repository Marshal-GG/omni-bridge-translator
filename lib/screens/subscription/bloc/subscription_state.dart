import 'package:equatable/equatable.dart';
import '../../../core/services/firebase/subscription_service.dart';

class SubscriptionState extends Equatable {
  final bool isLoading;
  final SubscriptionStatus? status;
  final List<SubscriptionPlan> plans;

  const SubscriptionState({
    this.isLoading = true,
    this.status,
    this.plans = const [],
  });

  SubscriptionState copyWith({
    bool? isLoading,
    SubscriptionStatus? status,
    List<SubscriptionPlan>? plans,
  }) {
    return SubscriptionState(
      isLoading: isLoading ?? this.isLoading,
      status: status ?? this.status,
      plans: plans ?? this.plans,
    );
  }

  @override
  List<Object?> get props => [isLoading, status, plans];
}

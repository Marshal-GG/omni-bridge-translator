import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/subscription_status.dart';
import '../../domain/usecases/get_subscription_status.dart';
import '../../domain/usecases/get_available_plans.dart';
import '../../domain/usecases/activate_trial.dart';
import '../../domain/usecases/open_checkout.dart';
import '../../domain/usecases/has_used_trial.dart';
import 'subscription_event.dart';
import 'subscription_state.dart';

class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  final GetSubscriptionStatus _getStatus;
  final GetAvailablePlans _getPlans;
  final ActivateTrial _activateTrial;
  final OpenCheckout _openCheckout;
  final HasUsedTrial _hasUsedTrial;

  StreamSubscription<SubscriptionStatus>? _statusSubscription;
  StreamSubscription<void>? _configSubscription;

  SubscriptionBloc({
    required GetSubscriptionStatus getStatus,
    required GetAvailablePlans getPlans,
    required ActivateTrial activateTrial,
    required OpenCheckout openCheckout,
    required HasUsedTrial hasUsedTrial,
  }) : _getStatus = getStatus,
       _getPlans = getPlans,
       _activateTrial = activateTrial,
       _openCheckout = openCheckout,
       _hasUsedTrial = hasUsedTrial,
       super(const SubscriptionState()) {
    on<SubscriptionLoaded>(_onLoaded);
    on<SubscriptionStatusUpdated>(_onStatusUpdated);
    on<SubscriptionActivateTrial>(_onActivateTrial);
    on<SubscriptionOpenCheckout>(_onOpenCheckout);

    // Initial load
    add(SubscriptionLoaded());

    // Listen to real-time status updates
    _statusSubscription = _getStatus().listen(
      (status) => add(SubscriptionStatusUpdated(status)),
    );

    // Listen to config changes
    _configSubscription = _getPlans.onChange.listen((_) {
      add(SubscriptionLoaded());
    });
  }

  Future<void> _onLoaded(
    SubscriptionLoaded event,
    Emitter<SubscriptionState> emit,
  ) async {
    final plans = _getPlans();
    final status = _getStatus.current;
    final trialUsed = await _hasUsedTrial();

    debugPrint(
      '[SubscriptionBloc] _onLoaded: ${plans.length} plans, '
      'status=${status?.tier ?? "null"}, trialUsed=$trialUsed',
    );

    emit(state.copyWith(
      isLoading: false,
      status: status,
      plans: plans,
      trialUsed: trialUsed,
    ));
  }

  void _onStatusUpdated(
    SubscriptionStatusUpdated event,
    Emitter<SubscriptionState> emit,
  ) {
    final plans = _getPlans();
    debugPrint(
      '[SubscriptionBloc] _onStatusUpdated: tier=${event.status.tier}, '
      '${plans.length} plans',
    );
    emit(state.copyWith(status: event.status, plans: plans));
  }

  Future<void> _onActivateTrial(
    SubscriptionActivateTrial event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    final error = await _activateTrial();
    if (error != null) {
      emit(state.copyWith(isLoading: false, error: error));
    } else {
      // Status will update via listener
      final trialUsed = await _hasUsedTrial();
      emit(state.copyWith(isLoading: false, trialUsed: trialUsed));
    }
  }

  Future<void> _onOpenCheckout(
    SubscriptionOpenCheckout event,
    Emitter<SubscriptionState> emit,
  ) async {
    await _openCheckout(event.tierId);
  }

  @override
  Future<void> close() {
    _statusSubscription?.cancel();
    _configSubscription?.cancel();
    return super.close();
  }
}

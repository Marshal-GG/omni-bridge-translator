import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omni_bridge/data/models/subscription_models.dart';
import 'package:omni_bridge/data/services/firebase/subscription_service.dart';
import 'package:omni_bridge/presentation/screens/subscription/bloc/subscription_event.dart';
import 'package:omni_bridge/presentation/screens/subscription/bloc/subscription_state.dart';

class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  final SubscriptionService _service;
  StreamSubscription<SubscriptionStatus>? _statusSubscription;

  SubscriptionBloc({SubscriptionService? service})
    : _service = service ?? SubscriptionService.instance,
      super(const SubscriptionState()) {
    on<SubscriptionLoaded>(_onLoaded);
    on<SubscriptionStatusUpdated>(_onStatusUpdated);

    // Auto-fetch data safely right upon creation
    add(SubscriptionLoaded());

    // Listen for real-time status updates from the service
    _statusSubscription = _service.statusStream.listen(
      (status) => add(SubscriptionStatusUpdated(status)),
    );

    // Also listen for config changes (plans becoming available)
    _service.configNotifier.addListener(_onConfigChanged);
  }

  void _onConfigChanged() {
    // Re-fetch plans when monetization config loads/changes
    add(SubscriptionLoaded());
  }

  Future<void> _onLoaded(
    SubscriptionLoaded event,
    Emitter<SubscriptionState> emit,
  ) async {
    final plans = _service.availablePlans;
    final status = _service.currentStatus;
    final trialUsed = await _service.hasUsedTrial();
    debugPrint(
      '[SubscriptionBloc] _onLoaded: ${plans.length} plans, '
      'status=${status?.tier ?? "null"}, trialUsed=$trialUsed',
    );
    emit(
      state.copyWith(
        isLoading: false,
        status: status,
        plans: plans,
        trialUsed: trialUsed,
      ),
    );
  }

  void _onStatusUpdated(
    SubscriptionStatusUpdated event,
    Emitter<SubscriptionState> emit,
  ) {
    final plans = _service.availablePlans;
    debugPrint(
      '[SubscriptionBloc] _onStatusUpdated: tier=${event.status.tier}, '
      '${plans.length} plans',
    );
    emit(state.copyWith(status: event.status, plans: plans));
  }

  @override
  Future<void> close() {
    _statusSubscription?.cancel();
    _service.configNotifier.removeListener(_onConfigChanged);
    return super.close();
  }
}

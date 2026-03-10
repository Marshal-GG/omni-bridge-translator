import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../models/subscription_models.dart';
import '../../../core/services/firebase/subscription_service.dart';
import 'subscription_event.dart';
import 'subscription_state.dart';

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
  }

  void _onLoaded(SubscriptionLoaded event, Emitter<SubscriptionState> emit) {
    // We already have plans statically accessible in the getter
    final plans = _service.availablePlans;
    final status = _service.currentStatus;

    emit(state.copyWith(isLoading: false, status: status, plans: plans));
  }

  void _onStatusUpdated(
    SubscriptionStatusUpdated event,
    Emitter<SubscriptionState> emit,
  ) {
    emit(
      state.copyWith(
        status: event.status,
        // refresh plans automatically in case there's an active monetization refetch in the background
        plans: _service.availablePlans,
      ),
    );
  }

  @override
  Future<void> close() {
    _statusSubscription?.cancel();
    return super.close();
  }
}

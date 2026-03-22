import 'dart:async';
import '../../domain/entities/subscription_plan.dart' as entity;
import '../../domain/entities/subscription_status.dart' as entity;
import '../../domain/repositories/i_subscription_repository.dart';
import '../../../../features/subscription/data/datasources/subscription_remote_datasource.dart';
import '../../../../features/subscription/data/models/subscription_dto.dart' as old;

class SubscriptionRepositoryImpl implements ISubscriptionRepository {
  final SubscriptionRemoteDataSource _service;

  SubscriptionRepositoryImpl({SubscriptionRemoteDataSource? service})
      : _service = service ?? SubscriptionRemoteDataSource.instance;

  @override
  Stream<entity.SubscriptionStatus> get statusStream =>
      _service.statusStream.map(_mapStatus);

  @override
  entity.SubscriptionStatus? get currentStatus =>
      _service.currentStatus != null ? _mapStatus(_service.currentStatus!) : null;

  @override
  List<entity.SubscriptionPlan> get availablePlans =>
      _service.availablePlans.map(_mapPlan).toList();

  @override
  Stream<void> get configChangeStream {
    final controller = StreamController<void>.broadcast();
    _service.configNotifier.addListener(() {
      if (!controller.isClosed) {
        controller.add(null);
      }
    });
    return controller.stream;
  }

  @override
  Future<void> init() async {
    _service.init();
  }

  @override
  Future<void> refreshStatus() async {
    // Current service doesn't have a public refreshStatus that is simple,
    // but we can trigger a fetch if we have a user.
  }

  @override
  Future<String?> activateTrial() async {
    return _service.activateTrial();
  }

  @override
  Future<void> openCheckout(String tierId) async {
    await _service.openCheckout(tierId);
  }

  @override
  Future<bool> hasUsedTrial() async {
    return _service.hasUsedTrial();
  }

  @override
  void dispose() {
    // Service is a singleton and managed elsewhere usually.
  }

  entity.SubscriptionStatus _mapStatus(old.SubscriptionStatus s) {
    return entity.SubscriptionStatus(
      tier: s.tier,
      dailyTokensUsed: s.dailyTokensUsed,
      weeklyTokensUsed: s.weeklyTokensUsed,
      monthlyTokensUsed: s.monthlyTokensUsed,
      lifetimeTokensUsed: s.lifetimeTokensUsed,
      dailyLimit: s.dailyLimit,
      dailyResetAt: s.dailyResetAt,
      periodLimit: s.periodLimit,
    );
  }

  entity.SubscriptionPlan _mapPlan(old.SubscriptionPlan p) {
    return entity.SubscriptionPlan(
      id: p.id,
      name: p.name,
      price: p.price,
      description: p.description,
      features: p.features,
      isPopular: p.isPopular,
      isTrial: p.isTrial,
      trialDurationHours: p.trialDurationHours,
      dailyTokens: p.dailyTokens,
      monthlyTokens: p.monthlyTokens,
      allowedTranslationModels: p.allowedTranslationModels,
      allowedTranscriptionModels: p.allowedTranscriptionModels,
      requestsPerMinute: p.requestsPerMinute,
      concurrentSessions: p.concurrentSessions,
      engineLimits: p.engineLimits,
    );
  }
}

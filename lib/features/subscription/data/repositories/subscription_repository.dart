import 'dart:async';
import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';
import '../../domain/entities/subscription_plan.dart';
import '../../domain/repositories/i_subscription_repository.dart';
import '../../../../features/subscription/data/datasources/subscription_remote_datasource.dart';

class SubscriptionRepositoryImpl implements ISubscriptionRepository {
  final SubscriptionRemoteDataSource _service;

  SubscriptionRepositoryImpl({SubscriptionRemoteDataSource? service})
    : _service = service ?? SubscriptionRemoteDataSource.instance;

  @override
  Stream<QuotaStatus> get statusStream => _service.statusStream;

  @override
  QuotaStatus? get currentStatus => _service.currentStatus;

  @override
  List<SubscriptionPlan> get availablePlans => _service.availablePlans;

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
    // Service handles updates via listeners
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
  int getLimitForTier(String tier) => _service.getLimitForTier(tier);

  @override
  int getPeriodLimitForTier(String tier) =>
      _service.getPeriodLimitForTier(tier);

  @override
  bool canUseModel(String engineId) => _service.canUseModel(engineId);

  @override
  bool isModelEnabled(String engineId) => _service.isModelEnabled(engineId);

  @override
  Map<String, int> engineLimits() => _service.engineLimits();

  @override
  String getPriceForTier(String tier) => _service.getPriceForTier(tier);

  @override
  String getNameForTier(String tier) => _service.getNameForTier(tier);

  @override
  String get defaultTier => _service.defaultTier;

  @override
  void dispose() {
    // Managed externally
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';
import '../../domain/entities/subscription_plan.dart';
import '../../domain/entities/billing_info.dart';
import '../../domain/entities/payment_event.dart';
import '../../domain/repositories/i_subscription_repository.dart';
import '../datasources/subscription_remote_datasource.dart';

class SubscriptionRepositoryImpl implements ISubscriptionRepository {
  final SubscriptionRemoteDataSource _service;

  SubscriptionRepositoryImpl({required SubscriptionRemoteDataSource service})
      : _service = service;

  // ── Quota status ────────────────────────────────────────────────────────
  @override
  Stream<QuotaStatus> get statusStream => _service.statusStream;

  @override
  QuotaStatus? get currentStatus => _service.currentStatus;

  // ── Plans ────────────────────────────────────────────────────────────────
  @override
  List<SubscriptionPlan> get availablePlans => _service.availablePlans;

  @override
  Stream<void> get configChangeStream {
    // ignore: close_sinks
    final controller = StreamController<void>.broadcast();
    _service.configNotifier.addListener(() {
      if (!controller.isClosed) controller.add(null);
    });
    return controller.stream;
  }

  // ── Billing state (reactive) ─────────────────────────────────────────────
  @override
  ValueNotifier<BillingInfo> get billingInfoNotifier =>
      _service.billingInfoNotifier;

  @override
  ValueNotifier<List<PaymentEvent>> get invoicesNotifier =>
      _service.invoicesNotifier;

  @override
  ValueNotifier<int> get configNotifier => _service.configNotifier;

  // ── Actions ──────────────────────────────────────────────────────────────
  @override
  Future<void> init() async => _service.init();

  @override
  Future<void> refreshStatus() async {}

  @override
  Future<String?> activateTrial() => _service.activateTrial();

  @override
  Future<String?> openCheckout(String tierId) => _service.openCheckout(tierId);

  @override
  Future<bool> hasUsedTrial() => _service.hasUsedTrial();

  @override
  Future<String?> cancelSubscription() => _service.cancelSubscription();

  @override
  Future<String?> resumeSubscription() => _service.resumeSubscription();

  // ── Tier helpers ─────────────────────────────────────────────────────────
  @override
  String get defaultTier => _service.defaultTier;

  @override
  List<String> get tierOrder => _service.tierOrder;

  @override
  int getTierRank(String tier) => _service.getTierRank(tier);

  @override
  bool isHighestTier(String tier) => _service.isHighestTier(tier);

  @override
  String getNameForTier(String tier) => _service.getNameForTier(tier);

  @override
  String getNameForRank(int rank) => _service.getNameForRank(rank);

  @override
  String getTierAt(int index) => _service.getTierAt(index);

  @override
  bool tierHasAccess(String currentTier, String requiredTier) =>
      _service.tierHasAccess(currentTier, requiredTier);

  @override
  String getRequirement(String category, String key, String fallback) =>
      _service.getRequirement(category, key, fallback);

  @override
  int getLimitForTier(String tier) => _service.getLimitForTier(tier);

  @override
  int getPeriodLimitForTier(String tier) =>
      _service.getPeriodLimitForTier(tier);

  @override
  String getPriceForTier(String tier) => _service.getPriceForTier(tier);

  // ── Model / engine access ────────────────────────────────────────────────
  @override
  bool canUseModel(String engineId) => _service.canUseModel(engineId);

  @override
  bool isModelEnabled(String engineId) => _service.isModelEnabled(engineId);

  @override
  Map<String, int> engineLimits([String? tier]) => _service.engineLimits(tier);

  @override
  int engineMonthlyLimit(String engineId, [String? tier]) =>
      _service.engineMonthlyLimit(engineId, tier);

  @override
  String? getModelType(String engineId) => _service.getModelType(engineId);

  @override
  String getModelDisplayName(String engineId) =>
      _service.getModelDisplayName(engineId);

  @override
  String get fallbackEngine => _service.fallbackEngine;

  @override
  List<String> allowedTranslationModels([String? tier]) =>
      _service.allowedTranslationModels(tier);

  @override
  List<String> allowedTranscriptionModels([String? tier]) =>
      _service.allowedTranscriptionModels(tier);

  @override
  bool shouldShowEngineLimitNotice(String engineId) =>
      _service.shouldShowEngineLimitNotice(engineId);

  // ── Config data ──────────────────────────────────────────────────────────
  @override
  int get pollIntervalSeconds => _service.pollIntervalSeconds;

  @override
  int get captionRetentionDays => _service.captionRetentionDays;

  @override
  Map<String, dynamic>? get upgradePromptConfig =>
      _service.upgradePromptConfig;

  @override
  void dispose() {}
}

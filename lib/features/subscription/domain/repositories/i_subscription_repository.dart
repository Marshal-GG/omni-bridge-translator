import 'package:flutter/foundation.dart';
import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';
import '../entities/subscription_plan.dart';
import '../entities/billing_info.dart';
import '../entities/payment_event.dart';

abstract class ISubscriptionRepository {
  // ── Quota status ──────────────────────────────────────────────────────────
  Stream<QuotaStatus> get statusStream;
  QuotaStatus? get currentStatus;

  // ── Plans ─────────────────────────────────────────────────────────────────
  List<SubscriptionPlan> get availablePlans;
  Stream<void> get configChangeStream;

  // ── Billing state (reactive) ──────────────────────────────────────────────
  ValueNotifier<BillingInfo> get billingInfoNotifier;
  ValueNotifier<List<PaymentEvent>> get invoicesNotifier;
  ValueNotifier<int> get configNotifier;

  // ── Actions ───────────────────────────────────────────────────────────────
  Future<void> init();
  Future<void> refreshStatus();
  Future<String?> activateTrial();
  Future<String?> openCheckout(String tierId);
  Future<bool> hasUsedTrial();
  Future<String?> cancelSubscription();
  Future<String?> resumeSubscription();

  // ── Tier helpers ──────────────────────────────────────────────────────────
  String get defaultTier;
  List<String> get tierOrder;
  int getTierRank(String tier);
  bool isHighestTier(String tier);
  String getNameForTier(String tier);
  String getNameForRank(int rank);
  String getTierAt(int index);
  bool tierHasAccess(String currentTier, String requiredTier);
  String getRequirement(String category, String key, String fallback);
  int getLimitForTier(String tier);
  int getPeriodLimitForTier(String tier);
  String getPriceForTier(String tier);

  // ── Model / engine access ─────────────────────────────────────────────────
  bool canUseModel(String engineId);
  bool isModelEnabled(String engineId);
  Map<String, int> engineLimits([String? tier]);
  int engineMonthlyLimit(String engineId, [String? tier]);
  String? getModelType(String engineId);
  String getModelDisplayName(String engineId);
  String get fallbackEngine;
  List<String> allowedTranslationModels([String? tier]);
  List<String> allowedTranscriptionModels([String? tier]);
  bool shouldShowEngineLimitNotice(String engineId);

  // ── Config data ───────────────────────────────────────────────────────────
  int get pollIntervalSeconds;
  int get captionRetentionDays;
  Map<String, dynamic>? get upgradePromptConfig;

  void dispose();
}

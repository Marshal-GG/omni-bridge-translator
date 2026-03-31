import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';
import '../entities/subscription_plan.dart';

abstract class ISubscriptionRepository {
  /// Stream of current subscription status.
  Stream<QuotaStatus> get statusStream;

  /// Returns the current subscription status (null if not loaded).
  QuotaStatus? get currentStatus;

  /// Returns the list of available subscription plans.
  List<SubscriptionPlan> get availablePlans;

  /// Stream that notifies when the monetization configuration changes.
  Stream<void> get configChangeStream;

  /// Initializes the subscription repository (listens to config, auth changes, etc.).
  Future<void> init();

  /// Refreshes the subscription status manually.
  Future<void> refreshStatus();

  /// Activates a one-time trial. Returns null on success, or an error message.
  Future<String?> activateTrial();

  /// Opens the checkout URL for a specific plan/tier.
  Future<void> openCheckout(String tierId);

  /// Checks if the user has already used their trial.
  Future<bool> hasUsedTrial();

  /// Returns the token limit for a specific tier.
  int getLimitForTier(String tier);

  /// Returns the period limit (monthly) for a specific tier.
  int getPeriodLimitForTier(String tier);

  /// Checks if a specific model/engine is included in the current plan.
  bool canUseModel(String engineId);

  /// Checks if a specific model/engine is enabled globally in the config.
  bool isModelEnabled(String engineId);

  /// Returns the per-engine limits for the current user's status.
  Map<String, int> engineLimits();

  /// Returns the price for a specific tier as a formatted string.
  String getPriceForTier(String tier);

  /// Returns the user-friendly name for a specific tier.
  String getNameForTier(String tier);

  /// The ID of the default (free) tier.
  String get defaultTier;

  /// Disposes resources.
  void dispose();
}

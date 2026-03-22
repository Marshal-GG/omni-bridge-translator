import '../entities/subscription_status.dart';
import '../entities/subscription_plan.dart';

abstract class ISubscriptionRepository {
  /// Stream of current subscription status.
  Stream<SubscriptionStatus> get statusStream;

  /// Returns the current subscription status (null if not loaded).
  SubscriptionStatus? get currentStatus;

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

  /// Disposes resources.
  void dispose();
}

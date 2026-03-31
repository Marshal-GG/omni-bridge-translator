/// Interface for components that need to reset their state upon user logout.
///
/// Implement this in data sources or repositories that hold user-specific
/// data, active streams, or timers which must be cleared to prevent
/// crosstalk between user accounts.
abstract class IResettable {
  /// Clears all local state and cancels active subscriptions or timers.
  void reset();
}

import 'package:omni_bridge/features/subscription/domain/repositories/i_subscription_repository.dart';
import '../entities/history_entry.dart';

/// Tier-aware filter for the History screen's live entry list. Lifts the
/// filter logic out of the screen widget so the rules live in domain.
///
/// Tier ranks (from `ISubscriptionRepository.getTierRank`):
///   0 — free       → empty (the screen renders a tier-gate view instead)
///   1 — trial      → all entries (session is the only window)
///   2 — pro        → entries from the last 3 days
///   ≥ 3 — enterprise → all entries (unlimited)
class GetVisibleHistoryUseCase {
  final ISubscriptionRepository subscription;

  GetVisibleHistoryUseCase(this.subscription);

  List<HistoryEntry> call(List<HistoryEntry> entries, String tier) {
    final rank = subscription.getTierRank(tier);
    if (rank == 0) return const [];
    if (rank >= 3) return entries;
    if (rank == 2) {
      final cutoff = DateTime.now().subtract(const Duration(days: 3));
      return entries.where((e) => e.timestamp.isAfter(cutoff)).toList();
    }
    // rank == 1 (trial) — session-only, return everything in memory.
    return entries;
  }
}

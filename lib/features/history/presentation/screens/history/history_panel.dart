import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omni_bridge/features/history/presentation/blocs/history_bloc.dart';
import 'package:omni_bridge/features/history/presentation/blocs/history_event.dart';
import 'package:omni_bridge/features/history/presentation/blocs/history_state.dart';
import 'package:omni_bridge/features/subscription/data/datasources/subscription_remote_datasource.dart';
import 'package:omni_bridge/features/history/domain/entities/history_entry.dart';
import 'package:omni_bridge/features/history/presentation/screens/history/components/history_header.dart';
import 'package:omni_bridge/features/history/presentation/screens/history/components/history_list_components.dart';
import 'package:omni_bridge/features/history/presentation/screens/history/components/history_entry_item.dart';

import 'package:omni_bridge/features/subscription/presentation/widgets/upgrade_sheet.dart';

class HistoryPanel extends StatelessWidget {
  const HistoryPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HistoryBloc, HistoryState>(
      builder: (context, state) {
        if (state is HistoryLoaded) {
          return _HistoryPanelBody(state: state);
        }
        return const Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

class _HistoryPanelBody extends StatefulWidget {
  final HistoryLoaded state;
  const _HistoryPanelBody({required this.state});

  @override
  State<_HistoryPanelBody> createState() => _HistoryPanelBodyState();
}

class _HistoryPanelBodyState extends State<_HistoryPanelBody> {
  @override
  void initState() {
    super.initState();
    if (SubscriptionRemoteDataSource.instance.getTierRank(
          widget.state.subscriptionStatus.tier,
        ) ==
        0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showUpgradeSheet(context);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tier = widget.state.subscriptionStatus.tier;
    final rank = SubscriptionRemoteDataSource.instance.getTierRank(tier);
    // Base tier (0): blocked entirely — showing upgrade sheet via callback above.
    if (rank == 0) {
      return WindowBorder(
        color: Colors.white10,
        width: 1,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF161616), Color(0xFF0F0F0F)],
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Column(
              children: [
                buildHistoryHeader(context, onClear: () {}),
                const Divider(height: 1, color: Colors.white10),
                Expanded(
                  child: _TierGateView(
                    icon: Icons.history_toggle_off,
                    title: 'History Unavailable',
                    subtitle:
                        'Upgrade to ${SubscriptionRemoteDataSource.instance.getNameForRank(1)} or higher plan to access your translation history.',
                    requiredTier:
                        '${SubscriptionRemoteDataSource.instance.getNameForRank(1)}+',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isPro = SubscriptionRemoteDataSource.instance.isHighestTier(tier);

    return WindowBorder(
      color: Colors.white10,
      width: 1,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF161616), Color(0xFF0F0F0F)],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              buildHistoryHeader(
                context,
                onClear: () =>
                    context.read<HistoryBloc>().add(ClearHistoryEvent()),
              ),
              const Divider(height: 1, color: Colors.white10),
              Expanded(
                child: Row(
                  children: [
                    // ── LEFT: Live Transcriptions ─────────────────────────────────────
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          buildHistoryColumnHeader(
                            '📝  Live Transcripts',
                            _historySubtitle(tier),
                          ),
                          const Divider(height: 1, color: Colors.white12),
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                final filtered = _filterByTier(
                                  widget.state.liveEntries,
                                  tier,
                                );
                                if (filtered.isEmpty) {
                                  return buildHistoryEmptyState(
                                    'No transcriptions yet.\nStart the live translator.',
                                  );
                                }
                                return _EntryList(
                                  entries: filtered,
                                  showTranslation: true,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Divider
                    Container(width: 1, color: Colors.white12),

                    // ── RIGHT: 5-Second Re-translations (Pro only) ────────────────────
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          buildHistoryColumnHeader(
                            '🔁  5-Second Re-translations',
                            'Cleaner, context-aware output',
                          ),
                          const Divider(height: 1, color: Colors.white12),
                          if (!isPro)
                            Expanded(
                              child: _TierGateView(
                                icon: Icons.auto_fix_high,
                                title:
                                    '${SubscriptionRemoteDataSource.instance.getNameForRank(SubscriptionRemoteDataSource.instance.getTierRank(tier) + 1)} Feature',
                                subtitle:
                                    'Upgrade to ${SubscriptionRemoteDataSource.instance.getNameForRank(SubscriptionRemoteDataSource.instance.getTierRank(tier) + 1)} to unlock Intelligent Context Refresh — '
                                    'AI that corrects translations up to 5 seconds back in real time.',
                                requiredTier: SubscriptionRemoteDataSource
                                    .instance
                                    .getNameForRank(
                                      SubscriptionRemoteDataSource.instance
                                              .getTierRank(tier) +
                                          1,
                                    ),
                              ),
                            )
                          else
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  final entries = widget.state.chunkedEntries;
                                  if (entries.isEmpty) {
                                    return buildHistoryEmptyState(
                                      'Chunks appear every 5 seconds\nonce translation is running.',
                                    );
                                  }
                                  return _EntryList(
                                    entries: entries,
                                    showTranslation: true,
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Subtitle shown under the Live Transcripts column header.
  String _historySubtitle(String tier) {
    final rank = SubscriptionRemoteDataSource.instance.getTierRank(tier);
    if (rank == 0) return 'No history available';
    if (rank == 1) return 'Current session only';
    if (rank == 2) return 'Last 3 days';
    return 'Unlimited history';
  }

  /// Filter entries based on the user's tier's history rank.
  List<HistoryEntry> _filterByTier(List<HistoryEntry> entries, String tier) {
    final rank = SubscriptionRemoteDataSource.instance.getTierRank(tier);
    if (rank >= 3) return entries; // Unlimited
    if (rank == 2) {
      final cutoff = DateTime.now().subtract(const Duration(days: 3));
      return entries.where((e) => e.timestamp.isAfter(cutoff)).toList();
    }
    // rank == 1 is session only, UI handles liveEntries lifetime.
    return entries;
  }
}

// ─── Tier gate placeholder ────────────────────────────────────────────────────

class _TierGateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String requiredTier;

  const _TierGateView({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.requiredTier,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.orangeAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Icon(icon, size: 32, color: Colors.orangeAccent),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.orangeAccent.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 12,
                    color: Colors.orangeAccent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Requires $requiredTier',
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, '/subscription'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.tealAccent,
                side: const BorderSide(color: Colors.tealAccent, width: 0.8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('View Plans', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Entry list ───────────────────────────────────────────────────────────────

class _EntryList extends StatefulWidget {
  final List<HistoryEntry> entries;
  final bool showTranslation;
  const _EntryList({required this.entries, required this.showTranslation});

  @override
  State<_EntryList> createState() => _EntryListState();
}

class _EntryListState extends State<_EntryList> {
  final ScrollController _scroll = ScrollController();

  @override
  void didUpdateWidget(_EntryList old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: widget.entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final entry = widget.entries[i];
        return buildHistoryEntryItem(entry);
      },
    );
  }
}

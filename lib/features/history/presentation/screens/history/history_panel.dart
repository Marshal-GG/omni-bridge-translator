import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:omni_bridge/core/di/di.dart';
import 'package:omni_bridge/core/navigation/app_router.dart';
import 'package:omni_bridge/core/theme/app_theme.dart';
import 'package:omni_bridge/core/widgets/omni_header.dart';
import 'package:omni_bridge/core/widgets/omni_search_bar.dart';
import 'package:omni_bridge/features/history/domain/entities/history_entry.dart';
import 'package:omni_bridge/features/history/domain/usecases/get_visible_history_usecase.dart';
import 'package:omni_bridge/features/history/presentation/blocs/history_bloc.dart';
import 'package:omni_bridge/features/history/presentation/blocs/history_event.dart';
import 'package:omni_bridge/features/history/presentation/blocs/history_state.dart';
import 'package:omni_bridge/features/shell/presentation/widgets/app_dashboard_shell.dart';
import 'package:omni_bridge/features/subscription/domain/repositories/i_subscription_repository.dart';
import 'components/history_day_group.dart';
import 'components/history_empty_state.dart';
import 'components/history_entry_card.dart';
import 'components/history_lang_metadata.dart';
import 'components/history_lang_sidebar.dart';
import 'components/history_tier_gate.dart';

/// Resolves the tier accent used across the History screen — same colour map
/// as Subscription (28) and Billing (29).
Color _accentForTier(String tier) => switch (tier.toLowerCase()) {
      'enterprise' => AppColors.splashPurple,
      'pro' => AppColors.accentTeal,
      'trial' => AppColors.amber,
      _ => AppColors.textSecondary,
    };

class HistoryPanel extends StatelessWidget {
  const HistoryPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return AppDashboardShell(
      currentRoute: AppRouter.historyPanel,
      header: OmniHeader(
        title: 'History',
        icon: Icons.history_rounded,
        onBack: () => Navigator.of(context).pop(),
      ),
      child: BlocBuilder<HistoryBloc, HistoryState>(
        builder: (context, state) {
          if (state is! HistoryLoaded) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentTeal),
            );
          }
          return _HistoryBody(state: state);
        },
      ),
    );
  }
}

class _HistoryBody extends StatelessWidget {
  final HistoryLoaded state;
  const _HistoryBody({required this.state});

  @override
  Widget build(BuildContext context) {
    final tier = state.subscriptionStatus.tier;
    final subscription = sl<ISubscriptionRepository>();
    final rank = subscription.getTierRank(tier);
    final hasChunked = subscription.isHighestTier(tier);
    final nextTierName = subscription.getNameForRank(rank + 1);

    // Free tier: full-screen tier gate.
    if (rank == 0) {
      final unlockTier = subscription.getNameForRank(1);
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _HeroBlock(
                  entryCount: 0,
                  search: '',
                  onSearchChanged: null,
                  onExport: null,
                  onClear: null,
                  canClear: false,
                ),
                const SizedBox(height: 24),
                HistoryTierGate(
                  icon: Icons.history_toggle_off_rounded,
                  title: 'History unavailable on Free',
                  body: 'Upgrade to $unlockTier or higher to keep a session '
                      'of your translation history.',
                  requiredTier: '$unlockTier+',
                ),
              ],
            ),
          ),
        ),
      );
    }

    final accent = _accentForTier(tier);

    // Tier-aware live history + search + lang filter, then reversed so the
    // newest entry sits at the top of the list.
    final visibleLive =
        sl<GetVisibleHistoryUseCase>().call(state.liveEntries, tier);
    final filteredLive = _applySearchAndLang(
      visibleLive,
      state.search,
      state.langFilter,
    ).reversed.toList(growable: false);

    // Right pane: 5-second re-translations. Same search + lang filter. No
    // tier-aware visibility filter (the whole pane is gated on hasChunked).
    final filteredChunked = _applySearchAndLang(
      state.chunkedEntries,
      state.search,
      state.langFilter,
    ).reversed.toList(growable: false);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeroBlock(
                entryCount: visibleLive.length,
                search: state.search,
                onSearchChanged: (q) =>
                    context.read<HistoryBloc>().add(HistorySearchChanged(q)),
                onExport: filteredLive.isEmpty
                    ? null
                    : () => _exportToClipboard(context, filteredLive),
                onClear: state.liveEntries.isEmpty
                    ? null
                    : () => _confirmAndClear(context),
                canClear: state.liveEntries.isNotEmpty,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 220,
                      child: HistoryLangSidebar(
                        accent: accent,
                        entries: state.liveEntries,
                        activeCode: state.langFilter,
                        onChanged: (code) => context
                            .read<HistoryBloc>()
                            .add(HistoryLangFilterChanged(code)),
                      ),
                    ),
                    Expanded(
                      child: _HistoryEntryList(
                        entries: filteredLive,
                        accent: accent,
                        hasUnfilteredEntries: state.liveEntries.isNotEmpty,
                        emptyTitle: 'No transcripts yet',
                        emptyBody:
                            'Start a translation session — captured transcripts will land here, newest on top.',
                        onDelete: (entry) => context
                            .read<HistoryBloc>()
                            .add(HistoryEntryDeleted(entry)),
                        onResetFilters: () {
                          final bloc = context.read<HistoryBloc>();
                          bloc.add(const HistorySearchChanged(''));
                          bloc.add(const HistoryLangFilterChanged('all'));
                        },
                      ),
                    ),
                    SizedBox(
                      width: 360,
                      child: _RetranslationPane(
                        entries: filteredChunked,
                        accent: accent,
                        unlocked: hasChunked,
                        nextTierName: nextTierName,
                        hasUnfilteredEntries:
                            state.chunkedEntries.isNotEmpty,
                        onDelete: (entry) => context
                            .read<HistoryBloc>()
                            .add(HistoryEntryDeleted(entry)),
                        onResetFilters: () {
                          final bloc = context.read<HistoryBloc>();
                          bloc.add(const HistorySearchChanged(''));
                          bloc.add(const HistoryLangFilterChanged('all'));
                        },
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

  List<HistoryEntry> _applySearchAndLang(
    List<HistoryEntry> entries,
    String search,
    String langFilter,
  ) {
    final q = search.trim().toLowerCase();
    return entries.where((e) {
      final matchSearch = q.isEmpty ||
          e.transcription.toLowerCase().contains(q) ||
          e.translation.toLowerCase().contains(q);
      final matchLang = langFilter == 'all' || e.sourceLang == langFilter;
      return matchSearch && matchLang;
    }).toList();
  }

  Future<void> _exportToClipboard(
    BuildContext context,
    List<HistoryEntry> entries,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final markdown = _entriesToMarkdown(entries);
    await Clipboard.setData(ClipboardData(text: markdown));
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Copied ${entries.length} ${entries.length == 1 ? 'entry' : 'entries'} to clipboard',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.accentTeal,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _entriesToMarkdown(List<HistoryEntry> entries) {
    final buffer = StringBuffer()
      ..writeln('| When | From | To | Original | Translation | Engine |')
      ..writeln('|---|---|---|---|---|---|');
    for (final e in entries) {
      final ts = e.timestamp.toIso8601String();
      final src = _escapeMd(e.transcription);
      final tgt = _escapeMd(e.translation);
      final engine = e.engine ?? '—';
      buffer.writeln(
        '| $ts | ${e.sourceLang} | ${e.targetLang} | $src | $tgt | $engine |',
      );
    }
    return buffer.toString();
  }

  String _escapeMd(String s) =>
      s.replaceAll('|', r'\|').replaceAll('\n', ' ');

  Future<void> _confirmAndClear(BuildContext context) async {
    final bloc = context.read<HistoryBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: AppShapes.lg),
        title: const Text(
          'Clear all history?',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
        ),
        content: const Text(
          'This permanently removes every translation entry stored on this '
          'device for the current session. This cannot be undone.',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text(
              'Clear All',
              style: TextStyle(color: AppColors.accentRed),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      bloc.add(ClearHistoryEvent());
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero block
// ─────────────────────────────────────────────────────────────────────────────

class _HeroBlock extends StatelessWidget {
  final int entryCount;
  final String search;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onExport;
  final VoidCallback? onClear;
  final bool canClear;

  const _HeroBlock({
    required this.entryCount,
    required this.search,
    required this.onSearchChanged,
    required this.onExport,
    required this.onClear,
    required this.canClear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Translation History',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _subtitle(entryCount),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        if (onSearchChanged != null)
          SizedBox(
            width: 240,
            child: OmniSearchBar(
              hintText: 'Search transcripts…',
              onChanged: onSearchChanged,
            ),
          ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: onExport,
          icon: const Icon(Icons.download_rounded, size: 13),
          label: const Text('Export'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: BorderSide(color: AppColors.white(0.10)),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            textStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(borderRadius: AppShapes.sm),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: canClear ? onClear : null,
          icon: const Icon(Icons.clear_all_rounded, size: 13),
          label: const Text('Clear All'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accentRed,
            side: BorderSide(color: AppColors.accentRed.withValues(alpha: 0.35)),
            backgroundColor: AppColors.accentRed.withValues(alpha: 0.05),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            textStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(borderRadius: AppShapes.sm),
          ),
        ),
      ],
    );
  }

  String _subtitle(int count) {
    if (count == 0) {
      return 'Session history — cleared on logout.';
    }
    return '$count ${count == 1 ? 'entry' : 'entries'} · session history — cleared on logout.';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Right pane — 5-second re-translations
// ─────────────────────────────────────────────────────────────────────────────

class _RetranslationPane extends StatelessWidget {
  final List<HistoryEntry> entries;
  final Color accent;
  final bool unlocked;
  final String nextTierName;
  final bool hasUnfilteredEntries;
  final ValueChanged<HistoryEntry> onDelete;
  final VoidCallback onResetFilters;

  const _RetranslationPane({
    required this.entries,
    required this.accent,
    required this.unlocked,
    required this.nextTierName,
    required this.hasUnfilteredEntries,
    required this.onDelete,
    required this.onResetFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.black_(0.18),
        border: Border(
          left: BorderSide(color: AppColors.cardBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.auto_fix_high_rounded,
                  size: 13,
                  color: AppColors.textDisabled,
                ),
                SizedBox(width: 8),
                Text(
                  '5-SEC RE-TRANSLATIONS',
                  style: TextStyle(
                    color: AppColors.textDisabled,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (!unlocked) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: HistoryTierGate(
          icon: Icons.auto_fix_high_rounded,
          title: '$nextTierName feature',
          body:
              'Intelligent Context Refresh — AI that corrects translations '
              'up to 5 seconds back in real time.',
          requiredTier: nextTierName,
        ),
      );
    }

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: HistoryEmptyState(
          kind: hasUnfilteredEntries
              ? HistoryEmptyKind.noMatch
              : HistoryEmptyKind.none,
          title: hasUnfilteredEntries ? null : 'No re-translations yet',
          body: hasUnfilteredEntries
              ? null
              : 'Re-translations appear every 5 seconds during a live session — '
                  'cleaner, context-aware output.',
          onResetFilters: hasUnfilteredEntries ? onResetFilters : null,
        ),
      );
    }

    final groups = <String, List<int>>{};
    for (var i = 0; i < entries.length; i++) {
      final label = historyDayLabel(entries[i].timestamp);
      groups.putIfAbsent(label, () => []).add(i);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final group in groups.entries)
            HistoryDayGroup(
              label: group.key,
              count: group.value.length,
              children: [
                for (final i in group.value)
                  HistoryEntryCard(
                    entry: entries[i],
                    accent: accent,
                    onDelete: () => onDelete(entries[i]),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Centre column — grouped entry list
// ─────────────────────────────────────────────────────────────────────────────

class _HistoryEntryList extends StatelessWidget {
  final List<HistoryEntry> entries;
  final Color accent;
  final bool hasUnfilteredEntries;
  final String emptyTitle;
  final String emptyBody;
  final ValueChanged<HistoryEntry> onDelete;
  final VoidCallback onResetFilters;

  const _HistoryEntryList({
    required this.entries,
    required this.accent,
    required this.hasUnfilteredEntries,
    required this.emptyTitle,
    required this.emptyBody,
    required this.onDelete,
    required this.onResetFilters,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: HistoryEmptyState(
          kind: hasUnfilteredEntries
              ? HistoryEmptyKind.noMatch
              : HistoryEmptyKind.none,
          title: hasUnfilteredEntries ? null : emptyTitle,
          body: hasUnfilteredEntries ? null : emptyBody,
          onResetFilters: hasUnfilteredEntries ? onResetFilters : null,
        ),
      );
    }

    final groups = <String, List<int>>{};
    for (var i = 0; i < entries.length; i++) {
      final label = historyDayLabel(entries[i].timestamp);
      groups.putIfAbsent(label, () => []).add(i);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final group in groups.entries)
            HistoryDayGroup(
              label: group.key,
              count: group.value.length,
              children: [
                for (final i in group.value)
                  HistoryEntryCard(
                    entry: entries[i],
                    accent: accent,
                    onDelete: () => onDelete(entries[i]),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}


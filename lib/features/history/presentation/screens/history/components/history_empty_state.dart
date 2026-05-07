import 'package:flutter/material.dart';

import 'package:omni_bridge/core/theme/app_theme.dart';

/// Visual variants the empty state can take.
enum HistoryEmptyKind {
  /// No entries captured yet — running translator hint.
  none,

  /// Has entries but the search/filter combination removed all of them.
  noMatch,
}

/// Centred empty-state placeholder used by the centre column.
class HistoryEmptyState extends StatelessWidget {
  final HistoryEmptyKind kind;

  /// Override the default title for the [HistoryEmptyKind.none] case so
  /// each pane can phrase its empty state differently.
  final String? title;

  /// Override the default body for the [HistoryEmptyKind.none] case.
  final String? body;
  final VoidCallback? onResetFilters;

  const HistoryEmptyState({
    required this.kind,
    this.title,
    this.body,
    this.onResetFilters,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, defaultTitle, defaultBody) = switch (kind) {
      HistoryEmptyKind.none => (
          Icons.history_edu_outlined,
          'No entries yet',
          'Start a translation session — captured transcripts will land here.',
        ),
      HistoryEmptyKind.noMatch => (
          Icons.search_off_rounded,
          'No matching entries',
          'Try a different search term or reset the filters.',
        ),
    };
    final resolvedTitle = title ?? defaultTitle;
    final resolvedBody = body ?? defaultBody;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: AppShapes.md,
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: AppColors.textFaint),
          const SizedBox(height: 14),
          Text(
            resolvedTitle,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            resolvedBody,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          if (kind == HistoryEmptyKind.noMatch && onResetFilters != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onResetFilters,
              icon: const Icon(Icons.refresh_rounded, size: 13),
              label: const Text('Reset filters'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentTeal,
                side: BorderSide(
                  color: AppColors.accentTeal.withValues(alpha: 0.4),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: AppShapes.sm),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

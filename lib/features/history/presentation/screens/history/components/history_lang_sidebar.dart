import 'package:flutter/material.dart';

import 'package:omni_bridge/core/theme/app_theme.dart';
import 'package:omni_bridge/features/history/domain/entities/history_entry.dart';
import 'history_lang_metadata.dart';
import 'history_storage_notice.dart';

/// Left column of the History screen — language pills (top 6 by frequency)
/// + storage notice card.
class HistoryLangSidebar extends StatelessWidget {
  /// Active filter — `'all'` or an ISO code.
  final String activeCode;

  /// All session entries (NOT the filtered list — counts must reflect the
  /// full set so the user can see what's available).
  final List<HistoryEntry> entries;

  /// Tier accent — used for the active pill highlight + the storage card
  /// upgrade CTA when applicable.
  final Color accent;

  final ValueChanged<String> onChanged;

  const HistoryLangSidebar({
    required this.activeCode,
    required this.entries,
    required this.accent,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final e in entries) {
      counts[e.sourceLang] = (counts[e.sourceLang] ?? 0) + 1;
    }
    final topLangs = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final shown = topLangs.take(6).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.black_(0.15),
        border: Border(
          right: BorderSide(color: AppColors.cardBorder),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeading('FILTER BY LANGUAGE'),
          const SizedBox(height: 8),
          _LangRow(
            active: activeCode == 'all',
            label: 'All languages',
            flag: '🌍',
            count: entries.length,
            accent: accent,
            onTap: () => onChanged('all'),
          ),
          for (final entry in shown)
            _LangRow(
              active: activeCode == entry.key,
              label: historyLangFor(entry.key).name,
              flag: historyLangFor(entry.key).flag,
              count: entry.value,
              accent: accent,
              onTap: () => onChanged(entry.key),
            ),
          const SizedBox(height: 18),
          const _SectionHeading('STORAGE'),
          const SizedBox(height: 8),
          const HistoryStorageNotice(),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String text;
  const _SectionHeading(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textDisabled,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}

class _LangRow extends StatefulWidget {
  final bool active;
  final String label;
  final String flag;
  final int count;
  final Color accent;
  final VoidCallback onTap;

  const _LangRow({
    required this.active,
    required this.label,
    required this.flag,
    required this.count,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_LangRow> createState() => _LangRowState();
}

class _LangRowState extends State<_LangRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final bg = widget.active
        ? accent.withValues(alpha: 0.10)
        : _hovered
            ? AppColors.white(0.025)
            : AppColors.transparent;
    final fg = widget.active ? accent : AppColors.textPrimary;
    final countBg = widget.active
        ? accent.withValues(alpha: 0.16)
        : AppColors.white(0.04);
    final countFg = widget.active ? accent : AppColors.textFaint;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppShapes.sm,
          ),
          child: Row(
            children: [
              Text(widget.flag, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: 11.5,
                    fontWeight: widget.active
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: countBg,
                  borderRadius: AppShapes.sm,
                ),
                child: Text(
                  '${widget.count}',
                  style: TextStyle(
                    color: countFg,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

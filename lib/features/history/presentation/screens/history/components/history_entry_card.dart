import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:omni_bridge/core/di/di.dart';
import 'package:omni_bridge/core/theme/app_theme.dart';
import 'package:omni_bridge/features/history/domain/entities/history_entry.dart';
import 'package:omni_bridge/features/subscription/domain/repositories/i_subscription_repository.dart';
import 'history_lang_metadata.dart';

/// Single row in the centre column of the History screen. Hover reveals
/// Copy + Delete actions; the row itself isn't a tap target — there's no
/// detail panel anymore.
class HistoryEntryCard extends StatefulWidget {
  final HistoryEntry entry;
  final Color accent;
  final VoidCallback onDelete;

  const HistoryEntryCard({
    required this.entry,
    required this.accent,
    required this.onDelete,
    super.key,
  });

  @override
  State<HistoryEntryCard> createState() => _HistoryEntryCardState();
}

class _HistoryEntryCardState extends State<HistoryEntryCard> {
  bool _hovered = false;
  bool _justCopied = false;

  Future<void> _copy() async {
    final entry = widget.entry;
    await Clipboard.setData(
      ClipboardData(text: '${entry.transcription}\n→ ${entry.translation}'),
    );
    if (!mounted) return;
    setState(() => _justCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _justCopied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final src = historyLangFor(entry.sourceLang);
    final tgt = historyLangFor(entry.targetLang);

    final bg = _hovered ? AppColors.white(0.025) : AppColors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppShapes.md,
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _LangPair(src: src, tgt: tgt, srcCode: entry.sourceLang, tgtCode: entry.targetLang),
                  const SizedBox(width: 8),
                  if (entry.engine != null)
                    Flexible(
                      child: Text(
                        sl<ISubscriptionRepository>().getModelDisplayName(entry.engine!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textFaint,
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    historyRelativeTime(entry.timestamp),
                    style: const TextStyle(
                      color: AppColors.textFaint,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (_hovered) ...[
                    const SizedBox(width: 6),
                    _IconBtn(
                      icon: _justCopied ? Icons.check_rounded : Icons.copy_rounded,
                      tone: _justCopied ? AppColors.accentTeal : AppColors.textMuted,
                      onTap: _copy,
                      tooltip: _justCopied ? 'Copied' : 'Copy',
                    ),
                    const SizedBox(width: 4),
                    _IconBtn(
                      icon: Icons.delete_outline_rounded,
                      tone: AppColors.accentRed,
                      onTap: widget.onDelete,
                      tooltip: 'Delete',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                entry.transcription,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12.5,
                  height: 1.5,
                ),
              ),
              if (entry.translation.isNotEmpty &&
                  entry.translation != entry.transcription) ...[
                const SizedBox(height: 4),
                Text(
                  entry.translation,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
  }
}

class _LangPair extends StatelessWidget {
  final HistoryLang src;
  final HistoryLang tgt;
  final String srcCode;
  final String tgtCode;
  const _LangPair({
    required this.src,
    required this.tgt,
    required this.srcCode,
    required this.tgtCode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.white(0.04),
        borderRadius: AppShapes.sm,
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(src.flag, style: const TextStyle(fontSize: 10)),
          const SizedBox(width: 4),
          Text(
            srcCode.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.arrow_forward_rounded,
            size: 10,
            color: AppColors.textDisabled,
          ),
          const SizedBox(width: 4),
          Text(tgt.flag, style: const TextStyle(fontSize: 10)),
          const SizedBox(width: 4),
          Text(
            tgtCode.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color tone;
  final VoidCallback onTap;
  final String tooltip;
  const _IconBtn({
    required this.icon,
    required this.tone,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.white(0.04),
            borderRadius: AppShapes.sm,
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Icon(icon, size: 11, color: tone),
        ),
      ),
    );
  }
}

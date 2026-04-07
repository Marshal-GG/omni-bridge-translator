import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omni_bridge/core/widgets/model_status_indicator.dart';
import 'package:omni_bridge/features/translation/presentation/blocs/translation_bloc.dart';
import 'package:omni_bridge/features/translation/presentation/blocs/translation_event.dart';
import 'package:omni_bridge/features/translation/presentation/blocs/translation_state.dart';
import 'package:omni_bridge/features/startup/presentation/notifiers/update_notifier.dart';
import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';

Widget buildTranslationHeader(BuildContext context, TranslationState state) {
  final bloc = context.read<TranslationBloc>();
  return SizedBox(
    height: 32,
    width: double.infinity,
    child: Row(
      children: [
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/support'),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Tooltip(
              message: 'Support & Feedback',
              child: Image.asset(
                'assets/app/icons/icon.png',
                width: 14,
                height: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Flexible(
          child: Text(
            'Omni Bridge: Live AI Translator',
            style: TextStyle(color: Colors.white70, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        _QuotaUsageText(status: state.quotaStatus),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => Navigator.pushNamed(
            context,
            '/settings-overlay',
            arguments: context.read<TranslationBloc>(),
          ),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Text(
              '${state.activeSourceLang.toLowerCase()} → ${state.activeTargetLang.toLowerCase()}',
              style: const TextStyle(
                color: Colors.tealAccent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        const SizedBox(width: 15),
        // Active Translation Model Status
        ModelStatusIndicator(
          status: state.modelStatuses[state.activeTranslationModelStatusKey],
          compact: true,
        ),
        const SizedBox(width: 8),
        // Active Transcription Model Status
        ModelStatusIndicator(
          status: state.modelStatuses[state.activeTranscriptionModelStatusKey],
          compact: true,
        ),
        const SizedBox(width: 15),
        Expanded(child: MoveWindow()),
        IconButton(
          icon: Icon(
            state.isRunning
                ? Icons.pause_circle_outline
                : Icons.play_circle_outline,
            size: 16,
            color: state.isRunning
                ? Colors.tealAccent
                : (state.isServerConnected ? Colors.redAccent : Colors.grey),
          ),
          onPressed: (state.isRunning || state.isServerConnected)
              ? () => bloc.add(ToggleRunningEvent())
              : null,
          tooltip: state.isRunning
              ? 'Pause Translation'
              : (state.isServerConnected
                    ? 'Resume Translation'
                    : 'Server Offline'),
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
          splashRadius: 16,
        ),
        IconButton(
          icon: const Icon(Icons.compress, size: 14, color: Colors.amberAccent),
          onPressed: () => bloc.add(ToggleShrinkEvent()),
          tooltip: 'Collapse to Captions',
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
          splashRadius: 16,
        ),
        IconButton(
          icon: const Icon(Icons.history, size: 14, color: Colors.greenAccent),
          onPressed: () => Navigator.pushNamed(context, '/history-panel'),
          tooltip: 'History',
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
          splashRadius: 16,
        ),

        // Settings button — navigates directly to settings overlay
        ValueListenableBuilder<bool>(
          valueListenable: UpdateNotifier.instance,
          builder: (context, hasUpdate, _) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.settings,
                    size: 14,
                    color: Colors.pinkAccent,
                  ),
                  tooltip: hasUpdate ? 'Settings — Update Available!' : 'Settings',
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/settings-overlay',
                    arguments: context.read<TranslationBloc>(),
                  ),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                  splashRadius: 16,
                ),
                if (hasUpdate)
                  Positioned(
                    right: 6,
                    top: 4,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF121212),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),

        MinimizeWindowButton(
          colors: WindowButtonColors(iconNormal: Colors.white),
        ),
        CloseWindowButton(
          colors: WindowButtonColors(
            iconNormal: Colors.white,
            mouseOver: Colors.red,
          ),
          onPressed: () => appWindow.close(),
        ),
      ],
    ),
  );
}

class _QuotaUsageText extends StatelessWidget {
  final QuotaStatus? status;
  const _QuotaUsageText({this.status});

  @override
  Widget build(BuildContext context) {
    final String tierName = status != null ? status!.tier.toUpperCase() : '...';
    final bool isUnlimited = status?.isUnlimited ?? false;

    final formatter = NumberFormat.compact();

    // Mirror the progress getter: period → monthly → daily
    final int usedTokens = status == null
        ? 0
        : status!.hasPeriodLimit || status!.hasMonthlyLimit
            ? status!.monthlyTokensUsed
            : status!.dailyTokensUsed;
    final int limitTokens = status == null
        ? 0
        : status!.hasPeriodLimit
            ? status!.periodLimit
            : status!.hasMonthlyLimit
                ? status!.monthlyLimit
                : status!.dailyLimit;

    final usedStr = status != null ? formatter.format(usedTokens) : '...';
    final limitStr = status != null
        ? (isUnlimited ? '∞' : formatter.format(limitTokens))
        : '...';

    final double progress = status?.progress ?? 0.0;
    final color = isUnlimited
        ? Colors.tealAccent
        : (progress > 0.9
              ? Colors.redAccent
              : (progress > 0.7 ? Colors.orangeAccent : Colors.tealAccent));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$usedStr / $limitStr',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              letterSpacing: 0.5,
            ),
          ),
          if (status != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                tierName,
                style: TextStyle(
                  color: color,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/translation_bloc.dart';
import '../bloc/translation_event.dart';
import '../bloc/translation_state.dart';
import '../../../core/services/update_service.dart';
import '../../../core/services/subscription_service.dart';

Widget buildTranslationHeader(BuildContext context, TranslationState state) {
  final bloc = context.read<TranslationBloc>();
  return SizedBox(
    height: 32,
    child: Row(
      children: [
        const SizedBox(width: 10),
        Image.asset('assets/icon.png', width: 14, height: 14),
        const SizedBox(width: 8),
        const Text(
          'Omni Bridge: Live AI Translator',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(width: 8),
        _QuotaUsageText(status: state.quotaStatus),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/settings-overlay'),
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
        const SizedBox(width: 15),
        Expanded(child: MoveWindow()),
        IconButton(
          icon: Icon(
            state.isRunning
                ? Icons.pause_circle_outline
                : Icons.play_circle_outline,
            size: 16,
            color: state.isRunning ? Colors.tealAccent : Colors.redAccent,
          ),
          onPressed: () => bloc.add(ToggleRunningEvent()),
          tooltip: state.isRunning ? 'Pause Translation' : 'Resume Translation',
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

        // Settings menu with orange badge dot when update is available
        ValueListenableBuilder<bool>(
          valueListenable: UpdateNotifier.instance,
          builder: (context, hasUpdate, _) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.settings,
                    size: 14,
                    color: Colors.pinkAccent,
                  ),
                  tooltip: 'Menu',
                  offset: const Offset(0, 32),
                  position: PopupMenuPosition.under,
                  color: const Color(0xFF1E1E1E),
                  elevation: 12,
                  constraints: const BoxConstraints(),
                  menuPadding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Colors.white10),
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      enabled: false,
                      padding: EdgeInsets.zero,
                      child: IntrinsicHeight(
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Config icon
                              Tooltip(
                                message: 'Configuration',
                                child: InkWell(
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.pushNamed(
                                      context,
                                      '/settings-overlay',
                                    );
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 10,
                                    ),
                                    child: Icon(
                                      Icons.handyman,
                                      size: 18,
                                      color: Colors.tealAccent,
                                    ),
                                  ),
                                ),
                              ),
                              const VerticalDivider(
                                width: 1,
                                thickness: 1,
                                color: Colors.white12,
                              ),
                              // Subscription icon
                              Tooltip(
                                message: 'Subscription & Quota',
                                child: InkWell(
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.pushNamed(
                                      context,
                                      '/subscription',
                                    );
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 10,
                                    ),
                                    child: Icon(
                                      Icons.workspace_premium_rounded,
                                      size: 18,
                                      color: Colors.lightBlueAccent,
                                    ),
                                  ),
                                ),
                              ),
                              const VerticalDivider(
                                width: 1,
                                thickness: 1,
                                color: Colors.white12,
                              ),
                              // Account icon
                              Tooltip(
                                message: 'Account',
                                child: InkWell(
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.pushNamed(
                                      context,
                                      '/account',
                                    );
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 10,
                                    ),
                                    child: Icon(
                                      Icons.manage_accounts_rounded,
                                      size: 18,
                                      color: Colors.purpleAccent,
                                    ),
                                  ),
                                ),
                              ),
                              const VerticalDivider(
                                width: 1,
                                thickness: 1,
                                color: Colors.white12,
                              ),
                              // About icon — shows update dot if available
                              Tooltip(
                                message: hasUpdate
                                    ? 'About — Update Available!'
                                    : 'About',
                                child: InkWell(
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.pushNamed(context, '/about');
                                  },
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 10,
                                        ),
                                        child: Icon(
                                          Icons.info_outline_rounded,
                                          size: 18,
                                          color: Colors.amberAccent,
                                        ),
                                      ),
                                      if (hasUpdate)
                                        Positioned(
                                          right: 4,
                                          top: 6,
                                          child: Container(
                                            width: 7,
                                            height: 7,
                                            decoration: const BoxDecoration(
                                              color: Colors.orangeAccent,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Orange badge dot on the settings gear itself
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
  final SubscriptionStatus? status;
  const _QuotaUsageText({this.status});

  @override
  Widget build(BuildContext context) {
    final String tierName = status?.tier.name.toUpperCase() ?? '...';
    final bool isPro = status?.tier == SubscriptionTier.pro;

    final formatter = NumberFormat.compact();
    final usedStr = status != null
        ? formatter.format(status!.dailyCharsUsed)
        : '...';
    final limitStr = status != null
        ? (isPro ? '∞' : formatter.format(status!.dailyLimit))
        : '...';

    final double progress = status?.progress ?? 0.0;
    final color = progress > 0.9
        ? Colors.redAccent
        : (progress > 0.7 ? Colors.orangeAccent : Colors.tealAccent);

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
              padding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 1.5,
              ),
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

import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/translation_bloc.dart';
import '../bloc/translation_event.dart';
import '../bloc/translation_state.dart';
import '../../../core/services/update_service.dart';

Widget buildTranslationHeader(BuildContext context, TranslationState state) {
  final bloc = context.read<TranslationBloc>();
  return SizedBox(
    height: 32,
    child: Row(
      children: [
        const SizedBox(width: 10),
        const Icon(Icons.translate, size: 14, color: Colors.tealAccent),
        const SizedBox(width: 8),
        const Text(
          'Omni Bridge: Live AI Translator',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () {
            if (!state.isSettingsOpen) {
              bloc.add(ToggleSettingsEvent());
            }
          },
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
        Expanded(child: MoveWindow()),
        IconButton(
          icon: const Icon(Icons.compress, size: 14, color: Colors.white70),
          onPressed: () => bloc.add(ToggleShrinkEvent()),
          tooltip: 'Collapse to Captions',
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
          splashRadius: 16,
        ),
        IconButton(
          icon: const Icon(Icons.history, size: 14, color: Colors.white70),
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
                    color: Colors.white54,
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
                                    if (!state.isSettingsOpen) {
                                      bloc.add(ToggleSettingsEvent());
                                    }
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
                              // Account icon
                              Tooltip(
                                message: 'Account',
                                child: InkWell(
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.pushNamed(context, '/account');
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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:omni_bridge/core/widgets/omni_window_layout.dart';
import 'package:omni_bridge/features/shell/presentation/widgets/app_navigation_rail.dart';
import 'package:omni_bridge/features/shell/presentation/widgets/shell_overlay.dart';
import 'package:omni_bridge/features/startup/presentation/notifiers/update_notifier.dart';

/// A wrapper layout that provides a global dashboard shell experience.
///
/// It places the [header] (typically an [OmniHeader] title-bar) spanning the
/// full window width at the top, followed by a [Row] containing the
/// [AppNavigationRail] on the left and the [child] content on the right.
///
/// This ensures the draggable title-bar and window controls span the entire
/// window rather than being confined to only the content area next to the rail.
class AppDashboardShell extends StatefulWidget {
  final Widget child;
  final String currentRoute;

  /// An optional full-width header (e.g. [OmniHeader]) rendered above the
  /// navigation rail + content row.
  final Widget? header;

  /// Index of the active settings sub-tab (forwarded to the nav rail).
  final int? settingsTabIndex;

  /// Callback when a settings sub-tab is clicked in the nav rail.
  final ValueChanged<int>? onSettingsTabChanged;

  /// Index of the active support sub-tab (forwarded to the nav rail).
  final int? supportTabIndex;

  /// Callback when a support sub-tab is clicked in the nav rail.
  final ValueChanged<int>? onSupportTabChanged;

  const AppDashboardShell({
    super.key,
    required this.child,
    required this.currentRoute,
    this.header,
    this.settingsTabIndex,
    this.onSettingsTabChanged,
    this.supportTabIndex,
    this.onSupportTabChanged,
  });

  @override
  State<AppDashboardShell> createState() => _AppDashboardShellState();
}

class _AppDashboardShellState extends State<AppDashboardShell> {
  @override
  void initState() {
    super.initState();
    // ── Debug: simulate an available update so the nav tile is always visible
    //    in development. Remove (or leave — it's gated by kDebugMode) before
    //    publishing a release build.
    if (kDebugMode) {
      Future.microtask(
        () => UpdateNotifier.instance.setAvailable(
          '2.0.0-preview',
          'https://github.com/Marshal-GG/omni-bridge-translator/releases',
          download:
              'https://github.com/Marshal-GG/omni-bridge-translator/releases/download/v2.0.0/OmniBridge-Setup.exe',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // During the window resize transition (e.g. navigating back to the
        // translation overlay), the dashboard shell briefly receives a very
        // small height constraint. Rendering at those constraints causes a
        // RenderFlex overflow in the nav rail Column. Return nothing until
        // the window is large enough to actually host the dashboard.
        // Suppress rendering below 350px tall — the window is either in
        // overlay territory (150px) or mid-transition. Avoids both the
        // RenderFlex overflow AND the briefly-wrong layout flash.
        if (constraints.maxHeight < 350) return const SizedBox.expand();

        return OmniWindowLayout(
          child: ShellOverlay(
            child: Column(
              children: [
                if (widget.header != null) ...[
                  widget.header!,
                  const Divider(height: 1, color: Colors.white10),
                ],
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppNavigationRail(
                        currentRoute: widget.currentRoute,
                        settingsTabIndex: widget.settingsTabIndex,
                        onSettingsTabChanged: widget.onSettingsTabChanged,
                        supportTabIndex: widget.supportTabIndex,
                        onSupportTabChanged: widget.onSupportTabChanged,
                      ),
                      Expanded(child: widget.child),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


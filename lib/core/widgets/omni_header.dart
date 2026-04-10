import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

/// The draggable title-bar header used across all Omni overlay windows.
///
/// Renders a 32px tall bar with a leading [icon] + [title], a draggable
/// [MoveWindow] region, and native minimize / close window buttons.
/// An optional back arrow is shown when [onBack] is provided.
///
/// Example:
/// ```dart
/// OmniHeader(
///   title: 'Settings',
///   icon: Icons.settings_outlined,
///   onBack: () => Navigator.pop(context),
/// )
/// ```
class OmniHeader extends StatelessWidget {
  /// The screen title displayed in the header.
  final String title;

  /// Leading icon shown before the title, tinted in tealAccent.
  final IconData icon;

  /// If provided, a back-arrow button is shown as the first item.
  final VoidCallback? onBack;

  /// Custom close handler. Defaults to [appWindow.close] if omitted.
  final VoidCallback? onClose;

  /// Optional action widgets rendered before the window buttons.
  final List<Widget>? actions;

  const OmniHeader({
    super.key,
    required this.title,
    required this.icon,
    this.onBack,
    this.onClose,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      color: Theme.of(context).appBarTheme.backgroundColor ?? Colors.black26,
      child: Row(
        children: [
          if (onBack != null)
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  size: 15,
                  color: Colors.white60,
                ),
                padding: EdgeInsets.zero,
                splashRadius: 16,
                hoverColor: Colors.white10,
                tooltip: 'Back',
              ),
            ),
          if (onBack == null) const SizedBox(width: 12),
          Icon(icon, size: 14, color: Colors.tealAccent),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          Expanded(child: MoveWindow()),
          if (actions != null) ...actions!,
          MinimizeWindowButton(
            colors: WindowButtonColors(iconNormal: Colors.white60),
          ),
          CloseWindowButton(
            colors: WindowButtonColors(
              iconNormal: Colors.white60,
              mouseOver: Colors.redAccent,
            ),
            onPressed: onClose ?? () => appWindow.close(),
          ),
        ],
      ),
    );
  }
}

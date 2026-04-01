import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

/// Root scaffold wrapper that applies a native window border and the
/// app surface color from the active theme.
///
/// Wrap every top-level screen with this to ensure consistent window
/// border rendering via `bitsdojo_window`'s [WindowBorder].
///
/// Example:
/// ```dart
/// OmniWindowLayout(child: MyScreen())
/// ```
class OmniWindowLayout extends StatelessWidget {
  /// The screen content to display inside the window border.
  final Widget child;

  const OmniWindowLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WindowBorder(
        color: Colors.white12,
        width: 1,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
          ),
          child: child,
        ),
      ),
    );
  }
}

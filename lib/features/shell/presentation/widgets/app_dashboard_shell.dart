import 'package:flutter/material.dart';
import 'package:omni_bridge/core/widgets/omni_window_layout.dart';
import 'package:omni_bridge/features/shell/presentation/widgets/app_navigation_rail.dart';

/// A wrapper layout that provides a global dashboard shell experience.
/// 
/// It encapsulates the standard `OmniWindowLayout` but injects the
/// `AppNavigationRail` on the left side, leaving the remaining space
/// for the [child]. The [currentRoute] dictates which nav item is highlighted.
class AppDashboardShell extends StatelessWidget {
  final Widget child;
  final String currentRoute;

  const AppDashboardShell({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    return OmniWindowLayout(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppNavigationRail(currentRoute: currentRoute),
          Expanded(child: child),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:omni_bridge/core/platform/window_manager.dart';
import 'package:omni_bridge/core/routes/routes_config.dart';

/// A comprehensive navigator observer for tracking app routing and access control.
/// It also handles window resizing and positioning based on the current screen.
class MyNavigatorObserver extends NavigatorObserver {
  /// Track the current user ID or login state
  String? currentUserID;

  MyNavigatorObserver({this.currentUserID});

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _handleWindowState(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _handleWindowState(newRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);

    // Only adjust window size if we are returning from an official main app route.
    // This prevents standard dialog dismissals (like DropdownSearch popups)
    // from triggering a window reset unexpectedly.
    final name = route.settings.name;
    if (name == '/login' ||
        name == '/translation-overlay' ||
        name == '/history-panel' ||
        name == '/subscription' ||
        name == '/about' ||
        name == '/account' ||
        name == '/settings-overlay' ||
        name == '/onboarding' ||
        name == '/splash') {
      if (previousRoute != null) {
        _handleWindowState(previousRoute);
      }
    }
  }

  void _handleWindowState(Route<dynamic> route) {
    final name = route.settings.name;
    if (name == null) return;
    
    debugPrint('[NavObserver] Routing to: $name');

    if (name == '/login') {
      setToLoginPosition();
    } else if (name == '/translation-overlay') {
      setToTranslationPosition();
    } else if (name == '/history-panel') {
      setToHistoryPosition();
    } else if (name == '/account') {
      setToAccountPosition();
    } else if (name == '/subscription') {
      setToSubscriptionPosition();
    } else if (name == '/about') {
      setToAboutPosition();
    } else if (name == '/settings-overlay') {
      setToSettingsPosition();
    } else if (name == '/onboarding' || name == '/splash') {
      setToStartupPosition();
    }
  }
}

import 'package:flutter/material.dart';
import 'package:omni_bridge/core/di/di.dart';
import 'package:omni_bridge/core/platform/window_manager.dart';
import 'package:omni_bridge/core/navigation/app_router.dart';
import 'package:omni_bridge/core/navigation/route_change_notifier.dart';

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

    final name = route.settings.name;
    if (name == AppRouter.login ||
        name == AppRouter.translationOverlay ||
        name == AppRouter.historyPanel ||
        name == AppRouter.subscription ||
        name == AppRouter.about ||
        name == AppRouter.account ||
        name == AppRouter.settingsOverlay ||
        name == AppRouter.usage ||
        name == AppRouter.support ||
        name == AppRouter.admin ||
        name == AppRouter.billing ||
        name == AppRouter.onboarding ||
        name == AppRouter.splash) {
      if (previousRoute != null) {
        _handleWindowState(previousRoute);
      }
    }
  }

  void _handleWindowState(Route<dynamic> route) {
    final name = route.settings.name;
    if (name == null) return;

    debugPrint('[NavObserver] Routing to: $name');

    // Notify via core-layer abstraction — no feature imports needed
    sl<RouteChangeNotifier>().onRouteChanged(name);

    if (name == AppRouter.login) {
      setToLoginPosition();
    } else if (name == AppRouter.translationOverlay) {
      setToTranslationPosition();
    } else if (name == AppRouter.historyPanel) {
      setToHistoryPosition();
    } else if (name == AppRouter.onboarding ||
        name == AppRouter.splash ||
        name == AppRouter.forceUpdate) {
      setToStartupPosition();
    } else if (name == AppRouter.subscription) {
      setToSubscriptionPosition();
    } else {
      setToDashboardPosition();
    }
  }
}

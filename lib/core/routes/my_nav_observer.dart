import 'package:flutter/material.dart';

/// A comprehensive navigator observer for tracking app routing and access control.
class MyNavigatorObserver extends NavigatorObserver {
  /// Track the current user ID or login state
  String? currentUserID;

  MyNavigatorObserver({this.currentUserID});

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logNavigationEvent('PUSH', route, previousRoute);
    _checkAccess(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _logNavigationEvent('POP', route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _logNavigationEvent('REMOVE', route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _logNavigationEvent('REPLACE', newRoute, oldRoute);
    if (newRoute != null) {
      _checkAccess(newRoute);
    }
  }

  void _logNavigationEvent(
    String action,
    Route<dynamic>? currentRoute,
    Route<dynamic>? otherRoute,
  ) {
    final currentName = _getRouteName(currentRoute);
    final otherName = _getRouteName(otherRoute);

    debugPrint('[NavObserver] $action: $otherName -> $currentName');
  }

  void _checkAccess(Route<dynamic> route) {
    final routeName = _getRouteName(route);

    if (_isProtectedRoute(routeName)) {
      if (currentUserID == null) {
        debugPrint(
          '[NavObserver] WARNING: Unauthenticated access attempt to $routeName',
        );
        // Handle redirect logic here
      } else {
        debugPrint(
          '[NavObserver] User $currentUserID accessed protected route: $routeName',
        );
      }
    }
  }

  String _getRouteName(Route<dynamic>? route) {
    if (route == null) return 'null';
    return route.settings.name ?? 'UnnamedRoute';
  }

  bool _isProtectedRoute(String routeName) {
    // Example: Routes beginning with '/protected/' or '/admin/'
    return routeName.startsWith('/protected/') ||
        routeName.startsWith('/admin/');
  }
}

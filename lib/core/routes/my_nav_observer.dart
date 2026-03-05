import '../window_manager.dart';
import 'routes_config.dart';

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
    if (previousRoute != null) {
      _handleWindowState(previousRoute);
    }
  }

  void _handleWindowState(Route<dynamic> route) {
    final name = route.settings.name;
    debugPrint('[NavObserver] Routing to: $name');

    if (name == '/login') {
      setToLoginPosition();
    } else if (name == '/translation-overlay') {
      setToTranslationPosition();
    } else if (name == '/history-panel') {
      setToHistoryPosition();
    }
  }
}

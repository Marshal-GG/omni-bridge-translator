/// Abstract notifier for route changes.
///
/// Lives in the core layer so infrastructure classes (e.g. NavigatorObserver)
/// can notify about route changes without importing feature-layer BLoC code.
abstract class RouteChangeNotifier {
  void onRouteChanged(String routeName);
}

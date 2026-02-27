import 'routes_config.dart';

Route<dynamic> generateRoute(RouteSettings settings) {
  final Map<String, WidgetBuilder> routes = {
    '/translation-overlay': (_) => TranslationOverlay(),
    '/settings-overlay': (_) => SettingsOverlay(),
  };
  final WidgetBuilder? builder = routes[settings.name];

  if (builder != null) {
    return MaterialPageRoute(
      builder: builder,
      settings: settings,
    );
  } else {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        body: Center(
          child: Text(
            'Page not found',
            style: TextStyle(fontSize: 24),
          ),
        ),
      ),
      settings: settings,
    );
  }
}

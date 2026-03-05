import 'routes_config.dart';

Route<dynamic> generateRoute(RouteSettings settings) {
  final Map<String, WidgetBuilder> routes = {
    '/login': (_) => const LoginScreen(),
    '/translation-overlay': (_) => const TranslationScreen(),
    '/settings-overlay': (_) => const SettingsScreen(),
    '/history-panel': (_) => const HistoryPanel(),
  };
  final WidgetBuilder? builder = routes[settings.name];

  if (builder != null) {
    return MaterialPageRoute(builder: builder, settings: settings);
  } else {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        body: Center(
          child: Text('Page not found', style: TextStyle(fontSize: 24)),
        ),
      ),
      settings: settings,
    );
  }
}

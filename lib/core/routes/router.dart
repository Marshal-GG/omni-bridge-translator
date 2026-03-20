import 'package:omni_bridge/core/routes/routes_config.dart';

Route<dynamic> generateRoute(RouteSettings settings) {
  final Map<String, WidgetBuilder> routes = {
    '/splash': (_) => const SplashScreen(),
    '/onboarding': (_) => const OnboardingScreen(),
    '/login': (_) => const LoginScreen(),
    '/translation-overlay': (_) => const TranslationScreen(),
    '/settings-overlay': (_) => const SettingsScreen(),
    '/history-panel': (_) => const HistoryPanel(),
    '/account': (_) => const AccountScreen(),
    '/about': (_) => const AboutScreen(),
    '/subscription': (_) => const SubscriptionScreen(),
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

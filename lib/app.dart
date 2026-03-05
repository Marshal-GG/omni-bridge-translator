import 'package:flutter/material.dart';
import 'core/routes/my_nav_observer.dart';
import 'core/routes/router.dart';
import 'core/services/auth_service.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Decide initial route based on current auth state
    final startRoute = AuthService.instance.isLoggedIn
        ? '/translation-overlay'
        : '/login';

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Omni Bridge: Live AI Translator',
      darkTheme: ThemeData.dark(),
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.transparent,
        canvasColor: Colors.transparent,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
      ),
      initialRoute: startRoute,
      onGenerateRoute: generateRoute,
      navigatorObservers: [MyNavigatorObserver()],
    );
  }
}

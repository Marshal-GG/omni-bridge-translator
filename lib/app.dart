import 'package:flutter/material.dart';
import 'core/routes/my_nav_observer.dart';
import 'core/routes/router.dart';

class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    // The Splash Screen handles routing to Onboarding or Login/Home
    final startRoute = initialRoute;

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

import 'package:flutter/material.dart';
import 'core/routes/my_nav_observer.dart';
import 'core/routes/router.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      initialRoute: "/translation-overlay",
      onGenerateRoute: generateRoute,
      navigatorObservers: [MyNavigatorObserver()],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:omni_bridge/core/navigation/app_router.dart';
import 'package:omni_bridge/core/routes/my_nav_observer.dart';
import 'package:omni_bridge/core/theme/app_theme.dart';
import 'package:omni_bridge/core/navigation/global_navigator.dart';

class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: GlobalNavigator.key,
      debugShowCheckedModeBanner: false,
      title: 'Omni Bridge: Live AI Translator',
      theme: AppTheme.darkTheme,
      initialRoute: initialRoute,
      onGenerateRoute: AppRouter.generateRoute,
      navigatorObservers: [MyNavigatorObserver()],
    );
  }
}

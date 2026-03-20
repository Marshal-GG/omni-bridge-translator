/*
 * Copyright (c) 2026 Omni Bridge. All rights reserved.
 * 
 * Licensed under the PERSONAL STUDY & LEARNING LICENSE v1.0.
 * Commercial use and public redistribution of modified versions are strictly prohibited.
 * See the LICENSE file in the project root for full license terms.
 */

import 'package:flutter/material.dart';
import 'package:omni_bridge/core/routes/my_nav_observer.dart';
import 'package:omni_bridge/core/routes/router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omni_bridge/core/theme/app_theme.dart';
import 'package:omni_bridge/presentation/screens/translation/bloc/translation_bloc.dart';
import 'package:omni_bridge/core/di/injection.dart';
import 'package:omni_bridge/presentation/screens/settings/bloc/settings_bloc.dart';
import 'package:omni_bridge/core/navigation/global_navigator.dart';

class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    // The Splash Screen handles routing to Onboarding or Login/Home
    final startRoute = initialRoute;

    return MultiBlocProvider(
      providers: [
        BlocProvider<TranslationBloc>(
          create: (_) => sl<TranslationBloc>(),
        ),
        BlocProvider<SettingsBloc>(
          create: (_) => sl<SettingsBloc>(),
        ),
      ],
      child: MaterialApp(
        navigatorKey: GlobalNavigator.key,
        debugShowCheckedModeBanner: false,
        title: 'Omni Bridge: Live AI Translator',
        theme: AppTheme.darkTheme,
        initialRoute: startRoute,
        onGenerateRoute: generateRoute,
        navigatorObservers: [MyNavigatorObserver()],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'core/routes/my_nav_observer.dart';
import 'core/routes/router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'screens/translation/bloc/translation_bloc.dart';
import 'screens/settings/bloc/settings_bloc.dart';
import 'core/services/asr_ws_client.dart';
import 'core/navigation/global_navigator.dart';

class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    // The Splash Screen handles routing to Onboarding or Login/Home
    final startRoute = initialRoute;

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => TranslationBloc(asrClient: AsrWebSocketClient()),
        ),
        BlocProvider(
          create: (context) => SettingsBloc(
            asrClient: context.read<TranslationBloc>().asrClient,
          ),
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

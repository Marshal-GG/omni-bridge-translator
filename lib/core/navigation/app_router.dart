import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omni_bridge/core/di/injection.dart';

// Feature Screens
import 'package:omni_bridge/features/startup/presentation/screens/splash_screen.dart';
import 'package:omni_bridge/features/startup/presentation/screens/onboarding_screen.dart';
import 'package:omni_bridge/features/auth/presentation/screens/login/login_screen.dart';
import 'package:omni_bridge/features/translation/presentation/screens/translation_screen.dart';
import 'package:omni_bridge/features/settings/presentation/screens/settings_screen.dart';
import 'package:omni_bridge/features/history/presentation/screens/history/history_panel.dart';
import 'package:omni_bridge/features/auth/presentation/screens/account/account_screen.dart';
import 'package:omni_bridge/features/about/presentation/screens/about_screen.dart';
import 'package:omni_bridge/features/subscription/presentation/screens/subscription_screen.dart';

// Blocs
import 'package:omni_bridge/features/translation/presentation/blocs/translation_bloc.dart';
import 'package:omni_bridge/features/settings/presentation/blocs/settings_bloc.dart';
import 'package:omni_bridge/features/about/presentation/blocs/about_bloc.dart';
import 'package:omni_bridge/features/about/presentation/blocs/about_event.dart';
import 'package:omni_bridge/features/startup/presentation/blocs/startup_bloc.dart';
import 'package:omni_bridge/features/startup/presentation/blocs/startup_event.dart';
import 'package:omni_bridge/features/auth/presentation/blocs/auth_bloc.dart';
import 'package:omni_bridge/features/history/presentation/blocs/history_bloc.dart';
import 'package:omni_bridge/features/history/presentation/blocs/history_event.dart';

class AppRouter {
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String translationOverlay = '/translation-overlay';
  static const String settingsOverlay = '/settings-overlay';
  static const String historyPanel = '/history-panel';
  static const String account = '/account';
  static const String about = '/about';
  static const String subscription = '/subscription';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => sl<StartupBloc>()..add(const StartupInitializeEvent()),
            child: const SplashScreen(),
          ),
          settings: settings,
        );
      case onboarding:
        return MaterialPageRoute(
          builder: (_) => const OnboardingScreen(),
          settings: settings,
        );
      case login:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => sl<AuthBloc>(),
            child: const LoginScreen(),
          ),
          settings: settings,
        );
      case translationOverlay:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => sl<TranslationBloc>(),
            child: const TranslationScreen(),
          ),
          settings: settings,
        );
      case settingsOverlay:
        // When navigating from within the translation screen, the caller
        // passes its live TranslationBloc as arguments so settings can read
        // the same accumulated modelStatuses. Other callers (login, subscription)
        // omit the argument and get a fresh instance.
        final passedBloc = settings.arguments is TranslationBloc
            ? settings.arguments as TranslationBloc
            : null;
        return MaterialPageRoute(
          builder: (_) => MultiBlocProvider(
            providers: [
              passedBloc != null
                  ? BlocProvider<TranslationBloc>.value(value: passedBloc)
                  : BlocProvider<TranslationBloc>(create: (_) => sl<TranslationBloc>()),
              BlocProvider<SettingsBloc>(create: (_) => sl<SettingsBloc>()),
            ],
            child: const SettingsScreen(),
          ),
          settings: settings,
        );
      case historyPanel:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => sl<HistoryBloc>()..add(LoadHistoryEvent()),
            child: const HistoryPanel(),
          ),
          settings: settings,
        );
      case account:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => sl<AuthBloc>(),
            child: const AccountScreen(),
          ),
          settings: settings,
        );
      case about:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => sl<AboutBloc>()..add(const AboutInitEvent()),
            child: const AboutScreen(),
          ),
          settings: settings,
        );
      case subscription:
        return MaterialPageRoute(
          builder: (_) => const SubscriptionScreen(),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text(
                'No route defined for ${settings.name}',
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          settings: settings,
        );
    }
  }
}

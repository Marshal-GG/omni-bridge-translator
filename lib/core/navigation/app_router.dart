import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omni_bridge/core/di/di.dart';
import 'package:omni_bridge/features/usage/presentation/screens/usage_screen.dart';

// Feature Screens
import 'package:omni_bridge/features/startup/presentation/screens/splash_screen.dart';
import 'package:omni_bridge/features/startup/presentation/screens/onboarding_screen.dart';
import 'package:omni_bridge/features/startup/presentation/screens/force_update_screen.dart';
import 'package:omni_bridge/features/auth/presentation/screens/login/login_screen.dart';
import 'package:omni_bridge/features/translation/presentation/screens/translation_screen.dart';
import 'package:omni_bridge/features/settings/presentation/screens/settings_screen.dart';
import 'package:omni_bridge/features/history/presentation/screens/history/history_panel.dart';
import 'package:omni_bridge/features/auth/presentation/screens/account/account_screen.dart';
import 'package:omni_bridge/features/about/presentation/screens/about_screen.dart';
import 'package:omni_bridge/features/subscription/presentation/screens/subscription_screen.dart';
import 'package:omni_bridge/features/support/presentation/screens/support_screen.dart';

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
  static const String usage = '/usage';
  static const String support = '/support';
  static const String forceUpdate = '/force_update';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return _fadeRoute(
          BlocProvider(
            create: (context) =>
                sl<StartupBloc>()..add(const StartupInitializeEvent()),
            child: const SplashScreen(),
          ),
          settings,
        );
      case onboarding:
        return _fadeRoute(const OnboardingScreen(), settings);
      case forceUpdate:
        return _fadeRoute(const ForceUpdateScreen(), settings);
      case login:
        return _fadeRoute(
          BlocProvider(
            create: (context) => sl<AuthBloc>(),
            child: const LoginScreen(),
          ),
          settings,
        );
      case translationOverlay:
        return _fadeRoute(
          BlocProvider(
            create: (_) => sl<TranslationBloc>(),
            child: const TranslationScreen(),
          ),
          settings,
        );
      case settingsOverlay:
        // When navigating from within the translation screen, the caller
        // passes its live TranslationBloc as arguments so settings can read
        // the same accumulated modelStatuses. Other callers (login, subscription)
        // omit the argument and get a fresh instance.
        final passedBloc = settings.arguments is TranslationBloc
            ? settings.arguments as TranslationBloc
            : null;
        return _fadeRoute(
          MultiBlocProvider(
            providers: [
              passedBloc != null
                  ? BlocProvider<TranslationBloc>.value(value: passedBloc)
                  : BlocProvider<TranslationBloc>(
                      create: (_) => sl<TranslationBloc>(),
                    ),
              BlocProvider<SettingsBloc>(create: (_) => sl<SettingsBloc>()),
            ],
            child: const SettingsScreen(),
          ),
          settings,
        );
      case historyPanel:
        return _fadeRoute(
          BlocProvider(
            create: (context) => sl<HistoryBloc>()..add(LoadHistoryEvent()),
            child: const HistoryPanel(),
          ),
          settings,
        );
      case account:
        return _fadeRoute(
          BlocProvider(
            create: (context) => sl<AuthBloc>(),
            child: const AccountScreen(),
          ),
          settings,
        );
      case about:
        return _fadeRoute(
          BlocProvider(
            create: (context) => sl<AboutBloc>()..add(const AboutInitEvent()),
            child: const AboutScreen(),
          ),
          settings,
        );
      case usage:
        return _fadeRoute(const UsageScreen(), settings);
      case subscription:
        return _fadeRoute(const SubscriptionScreen(), settings);
      case support:
        return _fadeRoute(const SupportScreen(), settings);
      default:
        return _fadeRoute(
          Scaffold(
            body: Center(
              child: Text(
                'No route defined for ${settings.name}',
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          settings,
        );
    }
  }

  static PageRouteBuilder _fadeRoute(Widget child, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: const Duration(milliseconds: 150),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }
}

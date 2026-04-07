import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:omni_bridge/firebase_options.dart';
import 'package:omni_bridge/core/config/app_config.dart';
import 'package:omni_bridge/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:omni_bridge/core/data/datasources/usage_metrics_remote_datasource.dart';
import 'package:omni_bridge/features/subscription/data/datasources/subscription_remote_datasource.dart';
import 'package:omni_bridge/core/platform/tray_manager.dart';
import 'package:omni_bridge/core/platform/window_manager.dart';
import 'package:omni_bridge/features/usage/data/datasources/usage_remote_datasource.dart';
import 'package:omni_bridge/core/network/rtdb_client.dart';
import 'package:omni_bridge/core/infrastructure/python_server_manager.dart';

import 'package:protocol_handler/protocol_handler.dart';
import 'package:app_links/app_links.dart';
import 'package:windows_single_instance/windows_single_instance.dart';
import 'package:omni_bridge/features/about/domain/entities/update_result.dart';
import 'package:omni_bridge/features/startup/data/datasources/update_remote_datasource.dart';
import 'dart:io' show Platform;
import 'package:omni_bridge/core/di/di.dart';
import 'package:omni_bridge/core/network/connectivity_service.dart';

class AppInitializer {
  /// Phase 1 — fast init. Completes before [runApp] so the window and tray
  /// are ready, but does NOT block on the server or any network calls.
  static Future<void> initFast(List<String> args) async {
    await setupInjection();
    ConnectivityService.instance.init();
    if (Platform.isWindows) {
      await WindowsSingleInstance.ensureSingleInstance(
        args,
        kDebugMode
            ? "omni_bridge_translator_instance_debug"
            : "omni_bridge_translator_instance",
        onSecondWindow: (newArgs) {
          debugPrint(
            '[SingleInstance] Second window detected with args: $newArgs',
          );
          if (newArgs.isNotEmpty) {
            for (final arg in newArgs) {
              String sanitized = arg.replaceAll('"', '').trim();
              if (sanitized.isEmpty) continue;

              final potentialUri = Uri.tryParse(sanitized);
              if (potentialUri != null && potentialUri.hasScheme) {
                final uriStr = potentialUri.toString();
                final isGoogleRedirect = uriStr.contains('oauth2redirect');
                final isAppRedirect = potentialUri.scheme == 'omni-bridge';

                if (isGoogleRedirect || isAppRedirect) {
                  debugPrint(
                    '[SingleInstance] Found matching redirect URI in args: $potentialUri',
                  );
                  AuthRemoteDataSource.instance.handleAuthRedirect(
                    potentialUri,
                  );
                  break;
                }
              }
            }
          }
        },
      );
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final appName = RTDBClient.appName;
      await Firebase.initializeApp(
        name: appName,
        options: DefaultFirebaseOptions.currentPlatform,
      );

      FlutterError.onError = (details) {
        debugPrint('Flutter Error: ${details.exceptionAsString()}');
        UsageMetricsRemoteDataSource.instance.logEvent(
          'Flutter Error: ${details.exceptionAsString()}',
          {'stackTrace': details.stack.toString()},
        );
        debugPrintStack(stackTrace: details.stack);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('Async Error: $error');
        UsageMetricsRemoteDataSource.instance.logEvent('Async Error', {
          'error': error.toString(),
        });
        debugPrintStack(stackTrace: stack);
        return true;
      };
    } catch (e) {
      debugPrint('Firebase initialization failed (missing config?): $e');
    }

    AuthRemoteDataSource.instance.init();
    SubscriptionRemoteDataSource.instance.init();
    UsageRemoteDataSource.instance.init(
      tierStream: SubscriptionRemoteDataSource.instance.statusStream,
      limitProvider: SubscriptionRemoteDataSource.instance.getLimitForTier,
      periodLimitProvider:
          SubscriptionRemoteDataSource.instance.getPeriodLimitForTier,
      defaultTierProvider: () =>
          SubscriptionRemoteDataSource.instance.defaultTier,
      pollIntervalProvider: () =>
          SubscriptionRemoteDataSource.instance.pollIntervalSeconds,
      engineLimitProvider:
          SubscriptionRemoteDataSource.instance.engineMonthlyLimit,
    );

    await initializeWindow();
    await initializeTray();

    if (!kIsWeb) {
      final protocol = kDebugMode ? 'omni-bridge-debug' : 'omni-bridge';
      await protocolHandler.register(protocol);

      final String clientId = AppConfig.googleClientId;
      if (clientId.isNotEmpty &&
          clientId.contains('.apps.googleusercontent.com')) {
        final String scheme = clientId.split('.').reversed.join('.');
        debugPrint('[Main] Registering Google Custom Scheme: $scheme');
        await protocolHandler.register(scheme);
      }
    }

    final appLinks = AppLinks();
    appLinks.uriLinkStream.listen((uri) {
      debugPrint('[DeepLink] Stream received: $uri');
      final uriStr = uri.toString();
      final isGoogleRedirect = uriStr.contains('oauth2redirect');
      final appProtocol = kDebugMode ? 'omni-bridge-debug' : 'omni-bridge';
      final isAppRedirect = uri.scheme == appProtocol;
      if (isGoogleRedirect || isAppRedirect) {
        AuthRemoteDataSource.instance.handleAuthRedirect(uri);
      }
    });

    try {
      final initialUri = await appLinks.getInitialLink();
      if (initialUri != null) {
        final uriStr = initialUri.toString();
        final isGoogleRedirect = uriStr.contains('oauth2redirect');
        final appProtocol = kDebugMode ? 'omni-bridge-debug' : 'omni-bridge';
        final isAppRedirect = initialUri.scheme == appProtocol;
        if (isGoogleRedirect || isAppRedirect) {
          AuthRemoteDataSource.instance.handleAuthRedirect(initialUri);
        }
      }
    } catch (e) {
      debugPrint('[DeepLink] Initial link error: $e');
    }

    unawaited(UsageMetricsRemoteDataSource.instance.logEvent('App Started (Dart Main)'));
  }

  /// Phase 2 — async init. Runs after [runApp] (driven by [StartupBloc]) so
  /// the splash screen is visible immediately. Starts the server in the
  /// background, validates the auth session, and checks for forced updates.
  /// Returns the resolved initial route.
  static Future<String> initAsync() async {
    // Start the Python server in the background — no need to wait for it.
    unawaited(PythonServerManager.startServer());

    final auth = FirebaseAuth.instanceFor(
      app: Firebase.app(RTDBClient.appName),
    );

    // Wait for auth state from local persistence — usually < 50 ms on desktop.
    try {
      await auth.authStateChanges().first.timeout(
        const Duration(milliseconds: 300),
      );
    } catch (_) {}

    User? currentUser = auth.currentUser;

    final results = await Future.wait([
      () async {
        if (currentUser == null) return false;
        try {
          await currentUser.reload();
          return auth.currentUser != null;
        } catch (e) {
          debugPrint('[AppInitializer] Auth Session Validation Failed: $e');
          if (e is FirebaseAuthException &&
              (e.code == 'user-not-found' || e.code == 'user-disabled')) {
            await auth.signOut();
          }
          return false;
        }
      }(),
      UpdateRemoteDataSource.instance.checkForUpdate().catchError((e) {
        debugPrint('[AppInitializer] Failed to check for forced updates: $e');
        return const UpdateResult(status: UpdateStatus.error);
      }),
    ]);

    final isLoggedIn = results[0] as bool;
    final updateResult = results[1] as UpdateResult;

    if (updateResult.status == UpdateStatus.forced) return '/force_update';
    if (isLoggedIn) return '/translation-overlay';
    return '/onboarding'; // not logged in → go straight to onboarding
  }
}

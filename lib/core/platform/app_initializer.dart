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

import 'package:protocol_handler/protocol_handler.dart';
import 'package:app_links/app_links.dart';
import 'package:windows_single_instance/windows_single_instance.dart';
import 'package:omni_bridge/features/about/domain/entities/update_result.dart';
import 'package:omni_bridge/features/startup/data/datasources/update_remote_datasource.dart';
import 'dart:io' show Platform;
import 'package:omni_bridge/core/di/di.dart';
import 'package:omni_bridge/core/network/connectivity_service.dart';

class AppInitializer {
  /// Initializes all required services and returns the calculated initial route
  static Future<String> init(List<String> args) async {
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
                  break; // Found it
                }
              }
            }
          }
        },
      );
    }

    try {
      // 1. Initialize Default App (satisfies plugins that expect [DEFAULT])
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // 2. Initialize Named App (provides true session isolation for Windows)
      final appName = RTDBClient.appName;
      await Firebase.initializeApp(
        name: appName,
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Fallback for desktop platforms without native crash tools
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

    // Initialize Auth (Mock for Windows compatibility)
    AuthRemoteDataSource.instance.init();

    // Initialize Subscription/Quota Service
    SubscriptionRemoteDataSource.instance.init();

    // Initialize Usage Service
    UsageRemoteDataSource.instance.init(
      tierStream: SubscriptionRemoteDataSource.instance.statusStream,
      limitProvider: SubscriptionRemoteDataSource.instance.engineMonthlyLimit,
      periodLimitProvider:
          SubscriptionRemoteDataSource.instance.getPeriodLimitForTier,
      defaultTierProvider: () =>
          SubscriptionRemoteDataSource.instance.defaultTier,
      pollIntervalProvider: () =>
          SubscriptionRemoteDataSource.instance.pollIntervalSeconds,
    );

    // Initialize the window and tray manager
    await initializeWindow();
    await initializeTray();

    // Register custom protocol for Windows
    if (!kIsWeb) {
      final protocol = kDebugMode ? 'omni-bridge-debug' : 'omni-bridge';
      await protocolHandler.register(protocol);

      // Also register the reversed Google Client ID as a protocol
      // This is required for the iOS Client ID redirection strategy
      final String clientId = AppConfig.googleClientId;
      if (clientId.isNotEmpty &&
          clientId.contains('.apps.googleusercontent.com')) {
        final String scheme = clientId.split('.').reversed.join('.');
        debugPrint('[Main] Registering Google Custom Scheme: $scheme');
        await protocolHandler.register(scheme);
      }
    }

    // Set up AppLinks listener for incoming auth redirects
    final appLinks = AppLinks();

    // 1. Handle links while the app is already running
    appLinks.uriLinkStream.listen((uri) {
      debugPrint('[DeepLink] Stream received: $uri');
      final uriStr = uri.toString();
      final isGoogleRedirect = uriStr.contains('oauth2redirect');
      final appProtocol = kDebugMode ? 'omni-bridge-debug' : 'omni-bridge';
      final isAppRedirect = uri.scheme == appProtocol;

      if (isGoogleRedirect || isAppRedirect) {
        debugPrint('[DeepLink] Passing stream URI to AuthRemoteDataSource');
        AuthRemoteDataSource.instance.handleAuthRedirect(uri);
      }
    });

    // 2. Handle the link that potentially launched the app
    try {
      final initialUri = await appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('[DeepLink] Initial URI caught: $initialUri');
        final uriStr = initialUri.toString();
        final isGoogleRedirect = uriStr.contains('oauth2redirect');
        final appProtocol = kDebugMode ? 'omni-bridge-debug' : 'omni-bridge';
        final isAppRedirect = initialUri.scheme == appProtocol;

        if (isGoogleRedirect || isAppRedirect) {
          debugPrint('[DeepLink] Passing initial URI to AuthRemoteDataSource');
          AuthRemoteDataSource.instance.handleAuthRedirect(initialUri);
        }
      }
    } catch (e) {
      debugPrint('[DeepLink] Initial link error: $e');
    }

    // Log App Launch Strategy
    UsageMetricsRemoteDataSource.instance.logEvent('App Started (Dart Main)');

    // Determine initial route

    // Use the named app instance for Auth (session isolation)
    final auth = FirebaseAuth.instanceFor(
      app: Firebase.app(RTDBClient.appName),
    );

    // Wait for initial auth state to be resolved (useful for desktop where it might take a moment to load from storage)
    try {
      await auth.authStateChanges().first.timeout(const Duration(seconds: 1));
    } catch (_) {
      // Timeout, proceed with current state
    }

    // Force a reload of the current user profile to ensure the session is still valid on the server.
    // This handles cases where the user was deleted/disabled in the Firebase Console while the app was closed.
    User? currentUser = auth.currentUser;
    if (currentUser != null) {
      try {
        await currentUser.reload();
        // Refresh the local user object after reload
        currentUser = auth.currentUser;
      } catch (e) {
        debugPrint('[AppInitializer] Auth Session Validation Failed: $e');
        // If the user is not found or account is disabled, sign out locally
        if (e is FirebaseAuthException &&
            (e.code == 'user-not-found' || e.code == 'user-disabled')) {
          await auth.signOut();
          currentUser = null;
        }
      }
    }

    // Use the updated currentUser state for root navigation
    final isLoggedIn = currentUser != null;

    String initialRoute = '/splash';
    if (isLoggedIn) {
      initialRoute = '/translation-overlay';
    }

    // Check for forced update before allowing the user into the app
    try {
      final updateResult = await UpdateRemoteDataSource.instance
          .checkForUpdate();
      if (updateResult.status == UpdateStatus.forced) {
        initialRoute = '/force_update';
      }
    } catch (e) {
      debugPrint('[AppInitializer] Failed to check for forced updates: $e');
    }

    return initialRoute;
  }
}

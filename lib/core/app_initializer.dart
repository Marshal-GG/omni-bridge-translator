import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../firebase_options.dart';
import 'services/auth_service.dart';
import 'services/tracking_service.dart';
import 'services/subscription_service.dart';
import 'tray_manager.dart';
import 'window_manager.dart';

import 'package:protocol_handler/protocol_handler.dart';
import 'package:app_links/app_links.dart';
import 'package:windows_single_instance/windows_single_instance.dart';
import 'dart:io' show Platform;

class AppInitializer {
  /// Initializes all required services and returns the calculated initial route
  static Future<String> init(List<String> args) async {
    if (Platform.isWindows) {
      await WindowsSingleInstance.ensureSingleInstance(
        args,
        "omni_bridge_translator_instance",
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
                  AuthService.instance.handleAuthRedirect(potentialUri);
                  break; // Found it
                }
              }
            }
          }
        },
      );
    }

    // Load environment variables from .env file
    await dotenv.load(fileName: '.env');

    try {
      // Initialize Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Fallback for desktop platforms without native crash tools
      FlutterError.onError = (details) {
        debugPrint('Flutter Error: ${details.exceptionAsString()}');
        TrackingService.instance.logError(
          'Flutter Error: ${details.exceptionAsString()}',
          details.stack,
        );
        debugPrintStack(stackTrace: details.stack);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('Async Error: $error');
        TrackingService.instance.logError('Async Error', error);
        debugPrintStack(stackTrace: stack);
        return true;
      };
    } catch (e) {
      debugPrint('Firebase initialization failed (missing config?): $e');
    }

    // Initialize Auth (Mock for Windows compatibility)
    AuthService.instance.init();

    // Initialize Subscription/Quota Service
    SubscriptionService.instance.init();

    // Initialize the window and tray manager
    await initializeWindow();
    await initializeTray();

    // Register custom protocol for Windows
    if (!kIsWeb) {
      await protocolHandler.register('omni-bridge');

      // Also register the reversed Google Client ID as a protocol
      // This is required for the iOS Client ID redirection strategy
      final String clientId = dotenv.env['GOOGLE_CLIENT_ID'] ?? '';
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
      final isAppRedirect = uri.scheme == 'omni-bridge';

      if (isGoogleRedirect || isAppRedirect) {
        debugPrint('[DeepLink] Passing stream URI to AuthService');
        AuthService.instance.handleAuthRedirect(uri);
      }
    });

    // 2. Handle the link that potentially launched the app
    try {
      final initialUri = await appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('[DeepLink] Initial URI caught: $initialUri');
        final uriStr = initialUri.toString();
        final isGoogleRedirect = uriStr.contains('oauth2redirect');
        final isAppRedirect = initialUri.scheme == 'omni-bridge';

        if (isGoogleRedirect || isAppRedirect) {
          debugPrint('[DeepLink] Passing initial URI to AuthService');
          AuthService.instance.handleAuthRedirect(initialUri);
        }
      }
    } catch (e) {
      debugPrint('[DeepLink] Initial link error: $e');
    }

    // Log App Launch Strategy
    TrackingService.instance.logEvent('App Started (Dart Main)');

    // Determine initial route

    // Wait for initial auth state to be resolved (useful for desktop where it might take a moment to load from storage)
    try {
      await FirebaseAuth.instance.authStateChanges().first.timeout(const Duration(seconds: 1));
    } catch (_) {
      // Timeout, proceed with current state
    }

    // Use FirebaseAuth directly since AuthService might not have initialized its ValueNotifier yet
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;

    String initialRoute = '/splash';
    if (isLoggedIn) {
      initialRoute = '/translation-overlay';
    }

    return initialRoute;
  }
}

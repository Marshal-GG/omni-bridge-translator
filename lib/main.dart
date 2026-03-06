import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'core/routes/routes_config.dart';
import 'core/tray_manager.dart';
import 'core/window_manager.dart';
import 'firebase_options.dart';
import 'core/services/tracking_service.dart';
import 'core/services/auth_service.dart';
import 'package:protocol_handler/protocol_handler.dart';
import 'package:app_links/app_links.dart';
import 'package:windows_single_instance/windows_single_instance.dart';
import 'dart:io' show Platform;

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    await WindowsSingleInstance.ensureSingleInstance(
      args,
      "omni_bridge_translator_instance",
      onSecondWindow: (newArgs) {
        debugPrint(
          '[SingleInstance] Second window detected with args: $newArgs',
        );
        if (newArgs.isNotEmpty) {
          final potentialUri = Uri.tryParse(newArgs.last);
          debugPrint(
            '[SingleInstance] Potential URI from second window: $potentialUri',
          );
          if (potentialUri != null) {
            final isGoogleRedirect =
                potentialUri.path.contains('oauth2redirect') ||
                potentialUri.host == 'oauth2redirect';
            final isAppRedirect = potentialUri.scheme == 'omni-bridge';

            if (isGoogleRedirect || isAppRedirect) {
              debugPrint(
                '[SingleInstance] Handling auth redirect for URI: $potentialUri',
              );
              AuthService.instance.handleAuthRedirect(potentialUri);
            } else {
              debugPrint(
                '[SingleInstance] URI did not match redirect patterns: $potentialUri',
              );
            }
          } else {
            debugPrint(
              '[SingleInstance] Could not parse URI from newArgs.last: ${newArgs.last}',
            );
          }
        } else {
          debugPrint(
            '[SingleInstance] No arguments provided to second window.',
          );
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
    final isGoogleRedirect =
        uri.path.contains('oauth2redirect') || uri.host == 'oauth2redirect';
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
      final isGoogleRedirect =
          initialUri.path.contains('oauth2redirect') ||
          initialUri.host == 'oauth2redirect';
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

  runApp(const MyApp());

  // Configure the main window once it is ready
  doWhenWindowReady(() {
    configureMainWindow();
  });
}

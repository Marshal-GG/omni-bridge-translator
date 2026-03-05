import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'core/routes/routes_config.dart';
import 'core/tray_manager.dart';
import 'core/window_manager.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      debugPrintStack(stackTrace: details.stack);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('Async Error: $error');
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

  runApp(const MyApp());

  // Configure the main window once it is ready
  doWhenWindowReady(() {
    configureMainWindow();
  });
}

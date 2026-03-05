import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'app.dart';
import 'core/routes/routes_config.dart';
import 'core/tray_manager.dart';
import 'core/window_manager.dart';
import 'core/blocs/firebase/app_bloc_observer.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Setup BLoC Observer for Firebase Analytics & Crashlytics
  Bloc.observer = AppBlocObserver();

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Catch fatal Flutter errors
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // Catch asynchronous Dart errors
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
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

import 'package:firebase_auth/firebase_auth.dart';
import 'routes/routes_config.dart';
import 'services/python_server_manager.dart';
import 'services/tracking_service.dart';

Future<void> initializeWindow() async {
  await Window.initialize();
  await windowManager.ensureInitialized();

  // Register window listener to catch close events
  windowManager.addListener(_AppWindowListener());

  // Start the Python Server
  await PythonServerManager.startServer();

  // 1. Define Window Options (HIDDEN HEADER)
  WindowOptions windowOptions = const WindowOptions(
    size: Size(800, 200),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}

void configureMainWindow() async {
  final win = appWindow;
  win.title = "Omni Bridge: Live AI Translator";

  // Use FirebaseAuth directly since AuthService might not have initialized its ValueNotifier yet
  if (FirebaseAuth.instance.currentUser != null) {
    win.minSize = const Size(300, 150);
    win.size = const Size(730, 150);
    win.alignment = Alignment.bottomCenter;
  } else {
    win.minSize = const Size(600, 500);
    win.size = const Size(880, 700);
    win.alignment = Alignment.center;
  }

  windowManager.setAlwaysOnTop(true);
  win.show();
}

/// Sets the window to a centered dialog style for Login
Future<void> setToLoginPosition() async {
  await windowManager.setResizable(true);
  appWindow.minSize = const Size(600, 500);
  await windowManager.setMinimumSize(const Size(600, 500));
  await windowManager.setSize(const Size(880, 700));
  await windowManager.center();
  await windowManager.setAlwaysOnTop(true);
}

/// Sets the window to a centered dialog style for Startup/Splash
Future<void> setToStartupPosition() async {
  await windowManager.setResizable(true);
  appWindow.minSize = const Size(600, 500);
  await windowManager.setMinimumSize(const Size(600, 500));
  await windowManager.setSize(const Size(880, 700));
  await windowManager.center();
  await windowManager.setAlwaysOnTop(true);
}

/// Sets window to the Account screen size (same as login)
Future<void> setToAccountPosition() async {
  await windowManager.setResizable(true);
  appWindow.minSize = const Size(600, 500);
  await windowManager.setMinimumSize(const Size(600, 500));
  await windowManager.setSize(const Size(800, 660));
  await windowManager.center();
  await windowManager.setAlwaysOnTop(false);
}

/// Sets the window to the About screen size (same as login)
Future<void> setToAboutPosition() async {
  await windowManager.setResizable(true);
  appWindow.minSize = const Size(600, 500);
  await windowManager.setMinimumSize(const Size(600, 500));
  await windowManager.setSize(const Size(880, 700));
  await windowManager.center();
  await windowManager.setAlwaysOnTop(false);
}

/// Sets the window to a centered large panel for Subscription
Future<void> setToSubscriptionPosition() async {
  await windowManager.setResizable(true);
  appWindow.minSize = const Size(600, 500);
  await windowManager.setMinimumSize(const Size(600, 500));
  await windowManager.setSize(const Size(1080, 820));
  await windowManager.center();
  await windowManager.setAlwaysOnTop(false);
}

/// Sets the window to the wide bottom-center overlay style
Future<void> setToTranslationPosition() async {
  await windowManager.setResizable(true);
  appWindow.minSize = const Size(300, 150); // Clear bitsdojo constraint
  // Set minimum size FIRST so that setSize isn't clamped by the old minSize
  await windowManager.setMinimumSize(const Size(400, 150));
  await windowManager.setSize(const Size(730, 150));

  // bitsdojo_window alignment
  appWindow.alignment = Alignment.bottomCenter;
  await windowManager.setAlwaysOnTop(true);
}

/// Sets the window to a large centered view for History
Future<void> setToHistoryPosition() async {
  await windowManager.setResizable(true);
  appWindow.minSize = const Size(600, 400); // Clear bitsdojo constraint
  await windowManager.setMinimumSize(const Size(600, 400));
  await windowManager.setSize(const Size(1000, 700));
  await windowManager.center();
  await windowManager.setAlwaysOnTop(false);
}

/// Sets the window to a centered panel for the Settings screen
Future<void> setToSettingsPosition() async {
  await windowManager.setResizable(true);
  appWindow.minSize = const Size(560, 480);
  await windowManager.setMinimumSize(const Size(560, 480));
  await windowManager.setSize(const Size(720, 620));
  await windowManager.center();
  await windowManager.setAlwaysOnTop(false);
}

class _AppWindowListener extends WindowListener {
  @override
  void onWindowClose() async {
    // End the Firebase tracing session gracefully before closing
    await TrackingService.instance.endSession();

    // Stop the Python server when the window is closed
    PythonServerManager.stopServer();

    // Default close behavior
    bool isPreventClose = await windowManager.isPreventClose();
    if (!isPreventClose) {
      await windowManager.destroy();
    }
  }
}

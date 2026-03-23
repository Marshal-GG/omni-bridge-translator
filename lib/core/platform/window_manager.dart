import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:window_manager/window_manager.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:omni_bridge/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:omni_bridge/core/infrastructure/python_server_manager.dart';
import 'package:omni_bridge/core/data/datasources/session_remote_datasource.dart';

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
  appWindow.title = "Omni Bridge: Live AI Translator";

  // Use FirebaseAuth through AuthRemoteDataSource for named instance isolation
  if (AuthRemoteDataSource.instance.auth.currentUser != null) {
    await windowManager.setResizable(true);
    await windowManager.setMinimumSize(const Size(300, 150));
    await windowManager.setSize(const Size(730, 150));
    appWindow.alignment = Alignment.bottomCenter;
  } else {
    await windowManager.setResizable(true);
    await windowManager.setMinimumSize(const Size(600, 500));
    await windowManager.setSize(const Size(880, 700));
    appWindow.alignment = Alignment.center;
    await windowManager.center();
  }

  await windowManager.setAlwaysOnTop(true);
  await windowManager.show();
}

/// Sets the window to a centered dialog style for Login
Future<void> setToLoginPosition() async {
  await windowManager.setResizable(true);
  await windowManager.setMinimumSize(const Size(600, 500));
  await windowManager.setSize(const Size(880, 700));
  appWindow.alignment = Alignment.center;
  await windowManager.center();
  await windowManager.setAlwaysOnTop(false);
}

/// Sets the window to a centered dialog style for Startup/Splash
Future<void> setToStartupPosition() async {
  await windowManager.setResizable(true);
  await windowManager.setMinimumSize(const Size(600, 500));
  await windowManager.setSize(const Size(880, 700));
  appWindow.alignment = Alignment.center;
  await windowManager.center();
  await windowManager.setAlwaysOnTop(true);
}

/// Sets window to the Account screen size
Future<void> setToAccountPosition() async {
  await windowManager.setResizable(true);
  await windowManager.setMinimumSize(const Size(1000, 500));
  await windowManager.setSize(const Size(1140, 800));
  appWindow.alignment = Alignment.center;
  await windowManager.center();
  await windowManager.setAlwaysOnTop(false);
}

/// Sets the window to the About screen size
Future<void> setToAboutPosition() async {
  await windowManager.setResizable(true);
  await windowManager.setMinimumSize(const Size(1000, 500));
  await windowManager.setSize(const Size(1140, 800));
  appWindow.alignment = Alignment.center;
  await windowManager.center();
  await windowManager.setAlwaysOnTop(false);
}

/// Sets the window to a centered large panel for Subscription
Future<void> setToSubscriptionPosition() async {
  await windowManager.setResizable(true);
  await windowManager.setMinimumSize(const Size(1000, 500));
  await windowManager.setSize(const Size(1140, 880));
  appWindow.alignment = Alignment.center;
  await windowManager.center();
  await windowManager.setAlwaysOnTop(false);
}

/// Sets the window to the wide bottom-center overlay style
Future<void> setToTranslationPosition() async {
  await windowManager.setResizable(true);
  // Reset constraints before setting new ones
  appWindow.minSize = const Size(300, 150);
  await windowManager.setMinimumSize(const Size(400, 150));
  await windowManager.setSize(const Size(730, 150));
  appWindow.alignment = Alignment.bottomCenter;
  await windowManager.setAlwaysOnTop(true);
}

/// Sets the window to a large centered view for History
Future<void> setToHistoryPosition() async {
  await windowManager.setResizable(true);
  await windowManager.setMinimumSize(const Size(600, 400));
  await windowManager.setSize(const Size(1000, 700));
  appWindow.alignment = Alignment.center;
  await windowManager.center();
  await windowManager.setAlwaysOnTop(false);
}

/// Sets the window to a centered panel for the Settings screen
Future<void> setToSettingsPosition() async {
  await windowManager.setResizable(true);
  await windowManager.setMinimumSize(const Size(1000, 500));
  await windowManager.setSize(const Size(1140, 800));
  appWindow.alignment = Alignment.center;
  await windowManager.center();
  await windowManager.setAlwaysOnTop(false);
}

class _AppWindowListener extends WindowListener {
  @override
  void onWindowClose() async {
    // End the Firebase tracing session gracefully before closing
    await SessionRemoteDataSource.instance.endSession();

    // Stop the Python server when the window is closed
    PythonServerManager.stopServer();

    // Default close behavior
    bool isPreventClose = await windowManager.isPreventClose();
    if (!isPreventClose) {
      await windowManager.destroy();
    }
  }
}

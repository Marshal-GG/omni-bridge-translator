import 'routes/routes_config.dart';
import 'services/python_server_manager.dart';

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
  // Check common initial state - default to Login dialog size since we start there
  final win = appWindow;
  win.minSize = const Size(400, 300);
  win.size = const Size(720, 480);
  win.alignment = Alignment.center;
  win.title = "Omni Bridge: Live AI Translator";

  windowManager.setAlwaysOnTop(true);
  win.show();
}

/// Sets the window to a centered dialog style for Login
Future<void> setToLoginPosition() async {
  await windowManager.setResizable(true);
  appWindow.minSize = const Size(400, 300); // Clear bitsdojo constraint
  await windowManager.setMinimumSize(const Size(400, 300));
  await windowManager.setSize(const Size(720, 480));
  await windowManager.center();
  await windowManager.setAlwaysOnTop(true);
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

class _AppWindowListener extends WindowListener {
  @override
  void onWindowClose() async {
    // Stop the Python server when the window is closed
    PythonServerManager.stopServer();

    // Default close behavior
    bool isPreventClose = await windowManager.isPreventClose();
    if (!isPreventClose) {
      await windowManager.destroy();
    }
  }
}

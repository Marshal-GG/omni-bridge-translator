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
  final win = appWindow;
  win.minSize = const Size(300, 150);
  win.size = const Size(730, 150);
  win.alignment = Alignment.bottomCenter;
  win.title = "Omni Bridge: Live AI Translator";

  windowManager.setAlwaysOnTop(true);

  // await Window.hideWindowControls();

  // Set acrylic effect for semi-transparent window
  // await Window.setEffect(
  //   effect: WindowEffect.acrylic,
  //   dark: true,
  //   // color: Colors.black.withOpacity(0.1), // Not working
  // );
  win.show();
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

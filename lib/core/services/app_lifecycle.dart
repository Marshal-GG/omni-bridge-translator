import 'package:omni_bridge/core/routes/routes_config.dart';

class AppLifecycle {
  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    await windowManager.ensureInitialized();

    // 1. Remove Title Bar & Transparent Background
    WindowOptions windowOptions = const WindowOptions(
      size: Size(800, 200),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden, // Hides OS Header
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    // 2. Setup System Tray (using tray_manager)
    await _setupTray();

    // 3. BitsDojo (for dragging)
    doWhenWindowReady(() {
      appWindow.show();
    });
  }

  static Future<void> _setupTray() async {
    final tray = TrayManager.instance;

    // Ensure 'app_icon.ico' exists in windows/runner/resources/
    await tray.setIcon('windows/runner/resources/app_icon.ico');
    await tray.setToolTip('Omni Bridge: Live AI Translator');

    // Create Tray Menu
    Menu menu = Menu(
      items: [
        MenuItem(
          key: 'show_app',
          label: 'Show Bar',
          onClick: (_) => windowManager.show(),
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'exit_app',
          label: 'Exit',
          onClick: (_) => windowManager.close(),
        ),
      ],
    );
    await tray.setContextMenu(menu);
  }
}

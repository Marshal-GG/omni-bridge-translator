import 'routes/routes_config.dart';

class TrayManager with TrayListener {
  Future<void> initializeTray() async {
    // Set the tray icon and tooltip
    await trayManager.setIcon('assets/icon.ico');
    trayManager.setToolTip("Omni Bridge: Live AI Translator");

    // Set up the context menu
    final trayMenu = Menu(
      items: [
        MenuItem(label: 'Show window', key: 'showWindow'),
        MenuItem(label: 'Check for updates...', key: ''),
        MenuItem(label: 'Settings', key: 'settings'),
        MenuItem(label: 'Quit', key: 'quit'),
      ],
    );
    await trayManager.setContextMenu(trayMenu);

    // Add the tray manager listener
    trayManager.addListener(this);
  }

  @override
  void onTrayIconMouseDown() async {
    bool isVisible = await windowManager.isVisible();
    if (isVisible) {
      await windowManager.hide();
    } else {
      await windowManager.show();
    }
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show':
        await windowManager.show();
        break;
      case 'settings':
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(builder: (context) => const SettingsOverlay()),
        // );
        break;
      case 'quit':
        await windowManager.close();
        break;
      default:
        break;
    }
  }
}

// Global instance of the TrayManager
final trayManagerInstance = TrayManager();
Future<void> initializeTray() => trayManagerInstance.initializeTray();

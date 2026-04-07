import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:omni_bridge/core/platform/window_manager.dart' show quitApp;

class OmniBridgeTrayManager with TrayListener {
  Future<void> initializeTray() async {
    await trayManager.setIcon('assets/app/icons/icon.ico');
    await trayManager.setToolTip('Omni Bridge — Live AI Translator');
    await _rebuildMenu();
    trayManager.addListener(this);
  }

  Future<void> _rebuildMenu() async {
    final menu = Menu(
      items: [
        MenuItem(label: 'Show Omni Bridge', key: 'show'),
        MenuItem.separator(),
        MenuItem(label: 'Settings', key: 'settings'),
        MenuItem(label: 'Check for Updates…', key: 'updates'),
        MenuItem.separator(),
        MenuItem(label: 'Quit Omni Bridge', key: 'quit'),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  @override
  // ignore: avoid_void_async
  void onTrayIconMouseDown() async {
    final isVisible = await windowManager.isVisible();
    if (isVisible) {
      final isFocused = await windowManager.isFocused();
      if (isFocused) {
        await windowManager.hide();
      } else {
        await windowManager.show();
        await windowManager.focus();
      }
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  // ignore: avoid_void_async
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show':
        await windowManager.show();
        await windowManager.focus();
        break;
      case 'settings':
        await windowManager.show();
        await windowManager.focus();
        // Navigate to settings via global navigator if available
        // (navigation is handled by the app when it becomes visible)
        break;
      case 'quit':
        await quitApp();
        break;
    }
  }
}

final _trayManager = OmniBridgeTrayManager();
Future<void> initializeTray() => _trayManager.initializeTray();

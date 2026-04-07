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

Future<void> configureMainWindow() async {
  appWindow.title = "Omni Bridge: Live AI Translator";

  // Use FirebaseAuth through AuthRemoteDataSource for named instance isolation
  if (AuthRemoteDataSource.instance.auth.currentUser != null) {
    await windowManager.setResizable(true);
    appWindow.minSize = const Size(300, 150);
    await windowManager.setMinimumSize(const Size(300, 150));
    await windowManager.setSize(const Size(730, 150));
    appWindow.alignment = Alignment.bottomCenter;
  } else {
    await windowManager.setResizable(true);
    appWindow.minSize = const Size(600, 500);
    await windowManager.setMinimumSize(const Size(600, 500));
    await windowManager.setSize(const Size(880, 700));
    appWindow.alignment = Alignment.center;
    await windowManager.center();
  }

  await windowManager.setAlwaysOnTop(true);
  await windowManager.show();
}

bool _isNavRailExpanded = false;
const double _navRailExpandedDiff =
    180.0; // navRailWidth (260) - navRailWidthCollapsed (80)

enum WindowMode { none, login, startup, translation, history, dashboard }

WindowMode _currentWindowMode = WindowMode.none;

/// Instantly resizes the OS window when the navigation rail expands or collapses.
Future<void> toggleNavRailWindowSize(bool isExpanded) async {
  if (_isNavRailExpanded == isExpanded) return;
  _isNavRailExpanded = isExpanded;

  Size currentSize = await windowManager.getSize();
  double newWidth =
      currentSize.width +
      (isExpanded ? _navRailExpandedDiff : -_navRailExpandedDiff);
  await windowManager.setSize(Size(newWidth, currentSize.height));
}

/// Sets the window to a centered dialog style for Login
Future<void> setToLoginPosition() async {
  if (_currentWindowMode == WindowMode.login) return;
  _currentWindowMode = WindowMode.login;

  await windowManager.setResizable(true);
  double addedWidth = _isNavRailExpanded ? _navRailExpandedDiff : 0.0;
  appWindow.minSize = Size(600 + addedWidth, 500);
  await windowManager.setMinimumSize(Size(600 + addedWidth, 500));
  await windowManager.setSize(Size(880 + addedWidth, 700));
  appWindow.alignment = Alignment.center;
  await windowManager.center();
  await windowManager.setAlwaysOnTop(false);
}

/// Sets the window to a centered dialog style for Startup/Splash
Future<void> setToStartupPosition() async {
  if (_currentWindowMode == WindowMode.startup) return;
  _currentWindowMode = WindowMode.startup;

  await windowManager.setResizable(true);
  double addedWidth = _isNavRailExpanded ? _navRailExpandedDiff : 0.0;
  appWindow.minSize = Size(600 + addedWidth, 500);
  await windowManager.setMinimumSize(Size(600 + addedWidth, 500));
  await windowManager.setSize(Size(880 + addedWidth, 700));
  appWindow.alignment = Alignment.center;
  await windowManager.center();
  await windowManager.setAlwaysOnTop(true);
}

/// Sets the window to the wide bottom-center overlay style
Future<void> setToTranslationPosition() async {
  if (_currentWindowMode == WindowMode.translation) return;
  _currentWindowMode = WindowMode.translation;

  await windowManager.setResizable(true);
  double addedWidth = _isNavRailExpanded ? _navRailExpandedDiff : 0.0;
  // Reset constraints before setting new ones
  appWindow.minSize = Size(300 + addedWidth, 150);
  await windowManager.setMinimumSize(Size(400 + addedWidth, 150));
  await windowManager.setSize(Size(730 + addedWidth, 150));
  appWindow.alignment = Alignment.bottomCenter;
  await windowManager.setAlignment(Alignment.bottomCenter);
  await windowManager.setAlwaysOnTop(true);
}

/// Sets the window to a large centered view for History
Future<void> setToHistoryPosition() async {
  if (_currentWindowMode == WindowMode.history) return;
  _currentWindowMode = WindowMode.history;

  await windowManager.setResizable(true);
  double addedWidth = _isNavRailExpanded ? _navRailExpandedDiff : 0.0;
  appWindow.minSize = Size(600 + addedWidth, 400);
  await windowManager.setMinimumSize(Size(600 + addedWidth, 400));
  await windowManager.setSize(Size(1000 + addedWidth, 700));
  appWindow.alignment = Alignment.center;
  await windowManager.center();
  await windowManager.setAlwaysOnTop(false);
}

/// A unified window size for all main dashboard screens.
Future<void> setToDashboardPosition() async {
  if (_currentWindowMode == WindowMode.dashboard) return;
  _currentWindowMode = WindowMode.dashboard;

  await windowManager.setResizable(true);
  double addedWidth = _isNavRailExpanded ? _navRailExpandedDiff : 0.0;
  appWindow.minSize = Size(1000 + addedWidth, 500);
  await windowManager.setMinimumSize(Size(1000 + addedWidth, 500));
  await windowManager.setSize(Size(1140 + addedWidth, 800));
  appWindow.alignment = Alignment.center;
  await windowManager.center();
  await windowManager.setAlwaysOnTop(false);
}

/// Called by the tray "Quit" item — exits the process cleanly.
Future<void> quitApp() async {
  await SessionRemoteDataSource.instance.endSession();
  PythonServerManager.stopServer();
  await windowManager.destroy();
}

class _AppWindowListener extends WindowListener {
  @override
  // ignore: avoid_void_async
  void onWindowClose() async {
    await SessionRemoteDataSource.instance.endSession();
    PythonServerManager.stopServer();
    await windowManager.destroy();
  }
}

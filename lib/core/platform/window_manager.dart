import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:window_manager/window_manager.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:omni_bridge/core/infrastructure/python_server_manager.dart';
import 'package:omni_bridge/core/data/datasources/session_remote_datasource.dart';

Future<void> initializeWindow() async {
  await Window.initialize();
  await windowManager.ensureInitialized();

  // Register window listener to catch close events
  windowManager.addListener(_AppWindowListener());

  // 1. Define Window Options (HIDDEN HEADER)
  WindowOptions windowOptions = const WindowOptions(
    size: Size(880, 700),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );

  // Prevent the OS from closing the window immediately on the X button —
  // onWindowClose() handles cleanup (server kill, session end) then destroys.
  await windowManager.setPreventClose(true);

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}

Future<void> configureMainWindow() async {
  // All geometry (size, position, alwaysOnTop) is owned by the nav observer
  // via setTo*Position(). This function only sets the window title, which
  // bitsdojo requires doWhenWindowReady to have fired before it can be set.
  appWindow.title = "Omni Bridge: Live AI Translator";
}

bool _isNavRailExpanded = false;
const double _navRailExpandedDiff =
    180.0; // navRailWidth (260) - navRailWidthCollapsed (80)

enum WindowMode { none, login, startup, translation, history, dashboard, subscription }

WindowMode _currentWindowMode = WindowMode.none;

// ── Smooth window transition ──────────────────────────────────────────────────
// Hides the window, runs all geometry changes off-screen, then fades back in.
// Eliminates the multi-step glitch caused by sequential native resize calls
// each triggering a separate OS repaint.

Future<void> _transitionWindow(Future<void> Function() work) async {
  await windowManager.setOpacity(0.0);
  await work();
  await windowManager.show();
  await windowManager.focus();
  // Fade in over ~120 ms (8 steps × 15 ms)
  for (var i = 1; i <= 8; i++) {
    await windowManager.setOpacity(i / 8);
    await Future.delayed(const Duration(milliseconds: 15));
  }
  await windowManager.setOpacity(1.0);
}

/// Instantly resizes the OS window when the navigation rail expands or collapses.
/// No transition — this happens while the window is already visible and the
/// content reflows smoothly on its own.
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

  await _transitionWindow(() async {
    await windowManager.setResizable(true);
    double addedWidth = _isNavRailExpanded ? _navRailExpandedDiff : 0.0;
    appWindow.minSize = Size(600 + addedWidth, 500);
    await windowManager.setMinimumSize(Size(600 + addedWidth, 500));
    await windowManager.setSize(Size(880 + addedWidth, 700));
    appWindow.alignment = Alignment.center;
    await windowManager.center();
    await windowManager.setAlwaysOnTop(false);
  });
}

/// Sets the window to a centered dialog style for Startup/Splash (Loader Size)
Future<void> setToStartupPosition() async {
  if (_currentWindowMode == WindowMode.startup) return;
  _currentWindowMode = WindowMode.startup;

  await _transitionWindow(() async {
    await windowManager.setResizable(true);
    appWindow.minSize = const Size(600, 500);
    await windowManager.setMinimumSize(const Size(600, 500));
    await windowManager.setSize(const Size(880, 700));
    appWindow.alignment = Alignment.center;
    await windowManager.center();
    await windowManager.setAlwaysOnTop(true);
  });
}

/// Sets the window to the wide bottom-center overlay style
Future<void> setToTranslationPosition() async {
  if (_currentWindowMode == WindowMode.translation) return;
  _currentWindowMode = WindowMode.translation;

  await _transitionWindow(() async {
    await windowManager.setResizable(true);
    double addedWidth = _isNavRailExpanded ? _navRailExpandedDiff : 0.0;
    appWindow.minSize = Size(300 + addedWidth, 150);
    await windowManager.setMinimumSize(Size(400 + addedWidth, 150));
    await windowManager.setSize(Size(730 + addedWidth, 150));
    appWindow.alignment = Alignment.bottomCenter;
    await windowManager.setAlignment(Alignment.bottomCenter);
    await windowManager.setAlwaysOnTop(true);
  });
}

/// Sets the window to a large centered view for History
Future<void> setToHistoryPosition() async {
  if (_currentWindowMode == WindowMode.history) return;
  _currentWindowMode = WindowMode.history;

  await _transitionWindow(() async {
    await windowManager.setResizable(true);
    double addedWidth = _isNavRailExpanded ? _navRailExpandedDiff : 0.0;
    appWindow.minSize = Size(600 + addedWidth, 400);
    await windowManager.setMinimumSize(Size(600 + addedWidth, 400));
    await windowManager.setSize(Size(1000 + addedWidth, 700));
    appWindow.alignment = Alignment.center;
    await windowManager.center();
    await windowManager.setAlwaysOnTop(false);
  });
}

/// Wider window for the subscription/plans screen.
Future<void> setToSubscriptionPosition() async {
  if (_currentWindowMode == WindowMode.subscription) return;
  _currentWindowMode = WindowMode.subscription;

  await _transitionWindow(() async {
    await windowManager.setResizable(true);
    double addedWidth = _isNavRailExpanded ? _navRailExpandedDiff : 0.0;
    appWindow.minSize = Size(1100 + addedWidth, 500);
    await windowManager.setMinimumSize(Size(1100 + addedWidth, 500));
    await windowManager.setSize(Size(1340 + addedWidth, 820));
    appWindow.alignment = Alignment.center;
    await windowManager.center();
    await windowManager.setAlwaysOnTop(false);
  });
}

/// A unified window size for all main dashboard screens.
Future<void> setToDashboardPosition() async {
  if (_currentWindowMode == WindowMode.dashboard) return;
  _currentWindowMode = WindowMode.dashboard;

  await _transitionWindow(() async {
    await windowManager.setResizable(true);
    double addedWidth = _isNavRailExpanded ? _navRailExpandedDiff : 0.0;
    appWindow.minSize = Size(1000 + addedWidth, 500);
    await windowManager.setMinimumSize(Size(1000 + addedWidth, 500));
    await windowManager.setSize(Size(1140 + addedWidth, 800));
    appWindow.alignment = Alignment.center;
    await windowManager.center();
    await windowManager.setAlwaysOnTop(false);
  });
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

/*
 * Copyright (c) 2026 Omni Bridge. All rights reserved.
 *
 * Licensed under the PERSONAL STUDY & LEARNING LICENSE v1.0.
 * Commercial use and public redistribution of modified versions are strictly prohibited.
 * See the LICENSE file in the project root for full license terms.
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

import 'package:omni_bridge/app.dart';
import 'package:omni_bridge/core/platform/app_initializer.dart';
import 'package:omni_bridge/core/platform/window_manager.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Phase 1: fast init — Firebase, DI, window, tray, protocols. No network.
  await AppInitializer.initFast(args);

  // Phase 2: resolve the initial route — checks auth state + forced updates.
  // Returns '/translation-overlay', '/force_update', or '/onboarding'.
  final String initialRoute = await AppInitializer.initAsync();

  runApp(MyApp(initialRoute: initialRoute));

  doWhenWindowReady(() {
    unawaited(configureMainWindow());
  });
}

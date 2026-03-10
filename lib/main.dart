/*
 * Copyright (c) 2026 Omni Bridge. All rights reserved.
 * 
 * Licensed under the PERSONAL STUDY & LEARNING LICENSE v1.0.
 * Commercial use and public redistribution of modified versions are strictly prohibited.
 * See the LICENSE file in the project root for full license terms.
 */

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_initializer.dart';
import 'core/services/update_service.dart';
import 'core/window_manager.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Run all app initializations and determine initial route
  String initialRoute = await AppInitializer.init(args);

  // Run the app with the determined route
  runApp(MyApp(initialRoute: initialRoute));

  // Configure the main window once it is ready
  doWhenWindowReady(() {
    configureMainWindow();
  });

  // Silent background update check — fire and forget
  UpdateService.instance.checkForUpdate().then((result) {
    if (result.status == UpdateStatus.available) {
      UpdateNotifier.instance.setAvailable(
        result.latestVersion!,
        result.releaseUrl!,
      );
    }
  });
}

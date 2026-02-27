import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

class PythonServerManager {
  static Process? _serverProcess;

  static Future<void> startServer() async {
    if (_serverProcess != null) return;

    try {
      final String appDir = path.dirname(Platform.resolvedExecutable);
      final String pyPath = path.join(appDir, 'omni_bridge_server.exe');

      if (File(pyPath).existsSync()) {
        debugPrint('Starting bundled Python server: $pyPath');
        _serverProcess = await Process.start(pyPath, []);

        // Wait for the server to be ready before allowing the app to proceed
        debugPrint('Waiting for server boot...');
        bool isReady = false;
        for (int i = 0; i < 20; i++) {
          try {
            final response = await http.get(
              Uri.parse('http://127.0.0.1:8765/status'),
            );
            if (response.statusCode == 200) {
              isReady = true;
              break;
            }
          } catch (_) {}
          await Future.delayed(const Duration(milliseconds: 500));
        }

        if (isReady) {
          debugPrint('Python server is ready.');
        } else {
          debugPrint('Warning: Python server boot timed out.');
        }
      } else {
        debugPrint(
          'Bundled server not found at $pyPath. Ensure the server is running manually in dev mode.',
        );
      }
    } catch (e) {
      debugPrint('Failed to start Python server: $e');
    }
  }

  static void stopServer() {
    if (_serverProcess != null) {
      debugPrint('Attempting to kill Python server process tree...');
      try {
        // PyInstaller creates a bootloader process -> python child process.
        // Process.runSync blocks the UI thread until the kill command completes.
        if (Platform.isWindows) {
          Process.runSync('taskkill', [
            '/F',
            '/IM',
            'omni_bridge_server.exe',
            '/T',
          ]);
        } else {
          _serverProcess!.kill();
        }
      } catch (e) {
        debugPrint('Error killing Python server: $e');
      }
      _serverProcess = null;
      debugPrint('Python server stopped.');
    }
  }
}

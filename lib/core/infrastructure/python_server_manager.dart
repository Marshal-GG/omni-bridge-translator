import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:omni_bridge/core/config/server_config.dart';

class PythonServerManager {
  static Process? _serverProcess;
  static bool _isIntentionalStop = false;
  static int _restartCount = 0;

  static Future<void> startServer() async {
    _isIntentionalStop = false;
    if (_serverProcess != null) return;

    try {
      // 1. Check if a server is already running externally (e.g. manually in dev mode)
      try {
        final checkResponse = await http
            .get(Uri.parse('${ServerConfig.httpUrl}/status'))
            .timeout(const Duration(seconds: 1));
        if (checkResponse.statusCode == 200) {
          debugPrint(
            '[PythonManager] Python server is already running externally.',
          );
          return;
        }
      } catch (_) {
        // Not running, proceed
      }

      final String appDir = path.dirname(Platform.resolvedExecutable);
      final String pyPath = path.join(appDir, 'omni_bridge_server.exe');

      if (File(pyPath).existsSync()) {
        // Kill any stray server processes before starting fresh (only if we found the bundled one)
        if (Platform.isWindows) {
          debugPrint(
            '[PythonManager] Killing stale server instances before start...',
          );
          Process.runSync('taskkill', [
            '/F',
            '/IM',
            'omni_bridge_server.exe',
            '/T',
          ]);
        }

        debugPrint('Starting bundled Python server: $pyPath');
        _serverProcess = await Process.start(
          pyPath,
          [],
          environment: {if (kDebugMode) 'OMNI_BRIDGE_DEBUG': 'true'},
        );

        // Pipe Python stdout/stderr to Flutter console for visibility
        _serverProcess!.stdout.transform(utf8.decoder).listen((data) {
          debugPrint('[Python Server STDOUT] ${data.trim()}');
        });
        _serverProcess!.stderr.transform(utf8.decoder).listen((data) {
          debugPrint('[Python Server STDERR] ${data.trim()}');
        });

        // Wait for the server to be ready before allowing the app to proceed
        debugPrint('Waiting for server boot...');
        bool isReady = false;
        // Increase timeout to 30 attempts (15 seconds)
        for (int i = 0; i < 30; i++) {
          try {
            final response = await http.get(
              Uri.parse('${ServerConfig.httpUrl}/status'),
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
          _restartCount = 0; // Reset counter on successful boot
        } else {
          debugPrint('Warning: Python server boot timed out.');
        }

        // Auto-restart logic for unexpected crashes
        _serverProcess!.exitCode.then((code) {
          debugPrint('[PythonManager] Process exited with code: $code');
          if (!_isIntentionalStop) {
            _serverProcess = null;
            _restartCount++;
            int delaySeconds = _restartCount > 3 ? 10 : 3; // Backoff
            debugPrint(
              '[PythonManager] Unexpected exit. Restarting in $delaySeconds seconds... (Attempt $_restartCount)',
            );
            Future.delayed(Duration(seconds: delaySeconds), () {
              if (!_isIntentionalStop) {
                startServer();
              }
            });
          }
        });
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
    _isIntentionalStop = true;
    _restartCount = 0;
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

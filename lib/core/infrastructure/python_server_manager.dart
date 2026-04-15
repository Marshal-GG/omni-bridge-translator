import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:omni_bridge/core/config/server_config.dart';
import 'package:omni_bridge/core/utils/app_logger.dart';

class PythonServerManager {
  static Process? _serverProcess;
  static bool _isIntentionalStop = false;
  static bool _isStarting = false;
  static int _restartCount = 0;
  static const String _tag = 'PythonManager';

  static Future<void> startServer() async {
    if (_isIntentionalStop) return;
    if (_serverProcess != null) return;
    if (_isStarting) return;
    _isStarting = true;
    _isIntentionalStop = false;

    try {
      // 1. Check if a server is already running externally (e.g. manually in dev mode)
      try {
        final checkResponse = await http
            .get(Uri.parse('${ServerConfig.httpUrl}/status'))
            .timeout(const Duration(seconds: 1));
        if (checkResponse.statusCode == 200) {
          AppLogger.i(
            'Python server is already running externally.',
            tag: _tag,
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
          AppLogger.i(
            'Killing stale server instances before start...',
            tag: _tag,
          );
          try {
            Process.runSync('taskkill', [
              '/F',
              '/IM',
              'omni_bridge_server.exe',
              '/T',
            ]);
          } catch (_) {
            // Expected on first boot — no stale process to kill
          }
        }

        AppLogger.i('Starting bundled Python server: $pyPath', tag: _tag);
        _serverProcess = await Process.start(
          pyPath,
          [],
          environment: {if (kDebugMode) 'OMNI_BRIDGE_DEBUG': 'true'},
        );

        // Pipe Python stdout/stderr to Flutter console for visibility
        _serverProcess!.stdout.transform(utf8.decoder).listen((data) {
          AppLogger.i(data.trim(), tag: 'PythonStdout');
        });
        _serverProcess!.stderr.transform(utf8.decoder).listen((data) {
          AppLogger.e(data.trim(), tag: 'PythonStderr');
        });

        AppLogger.i('Python server process started.', tag: _tag);
        _restartCount = 0;

        // Auto-restart logic for unexpected crashes
        unawaited(
          _serverProcess!.exitCode.then((code) {
            AppLogger.i('Process exited with code: $code', tag: _tag);
            if (!_isIntentionalStop) {
              _serverProcess = null;
              _restartCount++;
              int delaySeconds = _restartCount > 3 ? 10 : 3; // Backoff
              AppLogger.i(
                'Unexpected exit. Restarting in $delaySeconds seconds... (Attempt $_restartCount)',
                tag: _tag,
              );
              Future.delayed(Duration(seconds: delaySeconds), () {
                if (!_isIntentionalStop) {
                  startServer();
                }
              });
            }
          }),
        );
      } else {
        AppLogger.w(
          'Bundled server not found at $pyPath. Ensure the server is running manually in dev mode.',
          tag: _tag,
        );
      }
    } catch (e) {
      AppLogger.e('Failed to start Python server', error: e, tag: _tag);
    } finally {
      _isStarting = false;
    }
  }

  static void stopServer() {
    _isIntentionalStop = true;
    _restartCount = 0;
    AppLogger.i('Attempting to kill Python server process tree...', tag: _tag);
    try {
      if (Platform.isWindows) {
        // Kill by name — covers both bundled server (we have a handle) and the
        // case where _serverProcess is null (externally started / handle lost).
        // PyInstaller creates a bootloader → python child, so /T kills the tree.
        Process.runSync('taskkill', ['/F', '/IM', 'omni_bridge_server.exe', '/T']);
      } else if (_serverProcess != null) {
        _serverProcess!.kill();
      }
    } catch (e) {
      AppLogger.e('Error killing Python server', error: e, tag: _tag);
    }
    _serverProcess = null;
    AppLogger.i('Python server stopped.', tag: _tag);
  }
}

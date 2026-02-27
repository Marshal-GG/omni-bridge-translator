import 'dart:io';
import 'package:flutter/foundation.dart';

class PythonServerManager {
  static Process? _serverProcess;

  static Future<void> startServer() async {
    if (_serverProcess != null) return;

    try {
      debugPrint('Starting Python server...');

      // Start the Python process using the bat file or Python executable
      _serverProcess = await Process.start('server_env\\Scripts\\python.exe', [
        'server\\flutter_server.py',
      ]);

      _serverProcess?.stdout.listen((event) {
        debugPrint('Python: ${String.fromCharCodes(event)}');
      });
      _serverProcess?.stderr.listen((event) {
        debugPrint('Python Error: ${String.fromCharCodes(event)}');
      });

      debugPrint('Python server started with PID ${_serverProcess?.pid}');
    } catch (e) {
      debugPrint('Failed to start Python server: $e');
    }
  }

  static void stopServer() {
    if (_serverProcess != null) {
      debugPrint('Stopping Python server...');
      _serverProcess?.kill();
      _serverProcess = null;
    }
  }
}

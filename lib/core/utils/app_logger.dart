import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class AppLogger {
  AppLogger._();

  static void log(String message, {LogLevel level = LogLevel.info, String? tag, Object? error, StackTrace? stack}) {
    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase();
    final tagStr = tag != null ? ' [$tag]' : '';
    
    final output = '[$timestamp] $levelStr$tagStr $message';
    
    debugPrint(output);
    if (error != null) {
      debugPrint('  Error: $error');
    }
    if (stack != null) {
      debugPrint('  Stack: $stack');
    }
  }

  static void d(String message, {String? tag}) => log(message, level: LogLevel.debug, tag: tag);
  static void i(String message, {String? tag}) => log(message, level: LogLevel.info, tag: tag);
  static void w(String message, {String? tag}) => log(message, level: LogLevel.warning, tag: tag);
  static void e(String message, {String? tag, Object? error, StackTrace? stack}) => 
      log(message, level: LogLevel.error, tag: tag, error: error, stack: stack);
}

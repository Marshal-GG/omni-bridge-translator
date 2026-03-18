/// Central configuration for the local Python backend server.
/// Change [host] or [port] here to update all services at once.
class ServerConfig {
  static const String host = '127.0.0.1';
  static const int port = 8765;

  static String get wsUrl => 'ws://$host:$port';
  static String get httpUrl => 'http://$host:$port';
}

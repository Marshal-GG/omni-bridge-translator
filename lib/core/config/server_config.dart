/// Central configuration for the local Python backend server.
/// Change [host] or [port] here to update all services at once.
///
/// The server always binds to 127.0.0.1 (loopback). Plain `ws://` and
/// `http://` are intentional for localhost — traffic never leaves the
/// machine, so TLS adds no security benefit here. If [host] is ever
/// changed to a non-loopback address, the scheme properties below
/// automatically upgrade to `wss://` / `https://`.
class ServerConfig {
  static const String host = '127.0.0.1';
  static const int port = 8765;

  static bool get _isLocal =>
      host == '127.0.0.1' || host == 'localhost';

  static String get wsUrl =>
      '${_isLocal ? 'ws' : 'wss'}://$host:$port';

  static String get httpUrl =>
      '${_isLocal ? 'http' : 'https'}://$host:$port';
}

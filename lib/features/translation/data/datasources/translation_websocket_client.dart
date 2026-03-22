// lib/features/translation/data/datasources/translation_websocket_client.dart
//
// Connects to the Python WebSocket server (flutter_server.py) and
// streams live translated captions, with automatic reconnection.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:omni_bridge/features/translation/domain/entities/caption_message.dart';
import 'package:omni_bridge/features/translation/data/models/caption_dto.dart';

class TranslationWebsocketClient {
  final String serverHost;
  final int serverPort;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _captionController = StreamController<CaptionMessage>.broadcast();

  // Auto-reconnect state
  bool _intentionallyStopped = false;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _wasConnected = false;

  // Last known settings so we can re-send start on reconnect
  String _sourceLang = 'auto';
  String _targetLang = 'en';
  bool _useMic = false;
  int? _inputDeviceIndex;
  int? _outputDeviceIndex;
  String _translationModel = 'google';
  String _apiKey = '';
  String _googleCredentialsJson = '';
  String _transcriptionModel = 'online';

  String get _wsUrl => 'ws://$serverHost:$serverPort/captions';

  TranslationWebsocketClient({required this.serverHost, this.serverPort = 8765});

  /// Stream of incoming caption messages from the server
  Stream<CaptionMessage> get captions => _captionController.stream;

  /// Pre-connect the WebSocket without sending a start payload.
  /// Call this early (e.g. on construction) so the handshake is ready
  /// before the user presses play for the first time.
  void preConnect() {
    if (_channel != null) return; // already connected
    _intentionallyStopped = false;
    _connect(); // fire-and-forget; reconnect logic handles failures
  }

  /// Connect to server WebSocket then send start command.
  /// If already connected, skips the handshake and just re-sends the payload.
  Future<void> start({
    String sourceLang = 'auto',
    String targetLang = 'en',
    bool useMic = false,
    int? inputDeviceIndex,
    int? outputDeviceIndex,
    String translationModel = 'google',
    String apiKey = '',
    String googleCredentialsJson = '',
    String transcriptionModel = 'online',
  }) async {
    _intentionallyStopped = false;
    _sourceLang = sourceLang;
    _targetLang = targetLang;
    _useMic = useMic;
    _inputDeviceIndex = inputDeviceIndex;
    _outputDeviceIndex = outputDeviceIndex;
    _translationModel = translationModel;
    _apiKey = apiKey;
    _googleCredentialsJson = googleCredentialsJson;
    _transcriptionModel = transcriptionModel;
    _reconnectAttempt = 0;

    if (_channel != null) {
      // Already connected — skip handshake, just send the payload immediately.
      debugPrint('[WS] Already connected — sending start payload directly.');
      _sendStartPayload();
    } else {
      await _connect();
    }
  }

  Future<void> _connect() async {
    if (_intentionallyStopped) return;

    try {
      debugPrint('[WS] Attempting to connect to $_wsUrl...');
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));

      // Wait for the handshake to complete (throws if server is down)
      await _channel!.ready;

      // Connected — reset backoff
      bool isReconnect = _wasConnected;
      _wasConnected = true;
      _reconnectAttempt = 0;
      debugPrint('[WS] Connection established to $_wsUrl');

      if (isReconnect) {
        _captionController.add(
          CaptionMessage(
            text: 'Reconnected.',
            original: '',
            isError: false,
            isFinal: true,
            isSystemMessage: true,
          ),
        );
      }

      _sub = _channel!.stream.listen(
        (data) {
          try {
            final jsonMap = jsonDecode(data as String) as Map<String, dynamic>;
            _captionController.add(CaptionDto.fromJson(jsonMap));
          } catch (e, st) {
            debugPrint('[TranslationWebsocketClient] Failed to parse message: $e\n$st');
          }
        },
        onDone: () {
          debugPrint('[WS] Connection closed.');
          if (!_intentionallyStopped) {
            _captionController.add(
              CaptionMessage(
                text: '⚠ Server disconnected. Reconnecting…',
                original: '',
                isError: false,
                isFinal: true,
                isSystemMessage: true,
              ),
            );
            _scheduleReconnect();
          }
        },
        onError: (e) {
          debugPrint('[WS] Error: $e');
          if (!_intentionallyStopped) _scheduleReconnect();
        },
        cancelOnError: true,
      );

      // Send start command
      _sendStartPayload();
    } catch (e) {
      debugPrint('[WS] Connect failed: $e');
      if (!_intentionallyStopped) {
        if (_reconnectAttempt == 0) {
          // First failure — let the UI know
          _captionController.add(
            CaptionMessage(
              text: '⚠ Server not running. Retrying…',
              original: '',
              isError: false,
              isFinal: true,
              isSystemMessage: true,
            ),
          );
        }
        _scheduleReconnect();
      }
    }
  }

  void _scheduleReconnect() {
    _sub?.cancel();
    _sub = null;
    _channel = null;

    _reconnectAttempt++;
    // Exponential backoff: 2s, 4s, 8s … capped at 15s
    final delay = Duration(seconds: (_reconnectAttempt * 2).clamp(2, 15));
    debugPrint(
      '[WS] Reconnecting to $_wsUrl in ${delay.inSeconds}s (attempt $_reconnectAttempt)…',
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _connect);
  }

  void _sendStartPayload() {
    final payload = <String, dynamic>{
      'cmd': 'start',
      'source': _sourceLang,
      'target': _targetLang,
      'use_mic': _useMic,
      'translation_model': _translationModel,
      'transcription_model': _transcriptionModel,
      'api_key': _apiKey,
      'google_credentials_json': _googleCredentialsJson,
    };
    if (_inputDeviceIndex != null) {
      payload['input_device_index'] = _inputDeviceIndex;
    }
    if (_outputDeviceIndex != null) {
      payload['output_device_index'] = _outputDeviceIndex;
    }
    _channel?.sink.add(jsonEncode(payload));
  }

  /// Update active translation settings without reconnecting socket
  void updateSettings({
    required String sourceLang,
    required String targetLang,
    required bool useMic,
    int? inputDeviceIndex,
    int? outputDeviceIndex,
    double desktopVolume = 1.0,
    double micVolume = 1.0,
    required String translationModel,
    String apiKey = '',
    String googleCredentialsJson = '',
    String transcriptionModel = 'online',
  }) {
    _sourceLang = sourceLang;
    _targetLang = targetLang;
    _useMic = useMic;
    _inputDeviceIndex = inputDeviceIndex;
    _outputDeviceIndex = outputDeviceIndex;
    _translationModel = translationModel;
    _apiKey = apiKey;
    _googleCredentialsJson = googleCredentialsJson;
    _transcriptionModel = transcriptionModel;

    if (_channel != null) {
      final payload = <String, dynamic>{
        'cmd': 'settings_update',
        'source': sourceLang,
        'target': targetLang,
        'use_mic': useMic,
        'desktop_volume': desktopVolume,
        'mic_volume': micVolume,
        'translation_model': translationModel,
        'transcription_model': transcriptionModel,
        'api_key': apiKey,
        'google_credentials_json': googleCredentialsJson,
      };
      if (inputDeviceIndex != null) {
        payload['input_device_index'] = inputDeviceIndex;
      }
      if (outputDeviceIndex != null) {
        payload['output_device_index'] = outputDeviceIndex;
      }
      _channel!.sink.add(jsonEncode(payload));
    }
  }

  /// Instantly update audio capture volumes without restarting the pipeline
  void sendVolumeUpdate({
    required double desktopVolume,
    required double micVolume,
  }) {
    _channel?.sink.add(
      jsonEncode({
        'cmd': 'volume_update',
        'desktop_volume': desktopVolume,
        'mic_volume': micVolume,
      }),
    );
  }

  /// Soft-stop: sends stop to server but keeps WebSocket open.
  /// Use this for toggle-off so the next [start] fires immediately.
  void sendStopCommand() {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({'cmd': 'stop'}));
    }
  }

  /// Hard-stop: send stop, close WebSocket, cancel auto-reconnect.
  /// Use this only on app shutdown.
  Future<void> stop() async {
    _intentionallyStopped = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _sub?.cancel();
    _sub = null;
    _channel?.sink.add(jsonEncode({'cmd': 'stop'}));
    await Future.delayed(const Duration(milliseconds: 300));
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    stop();
    _captionController.close();
  }
}

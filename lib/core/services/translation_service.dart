// lib/core/services/translation_service.dart
//
// Connects to the Python WebSocket server (flutter_server.py) and
// streams live translated captions, with automatic reconnection.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class CaptionMessage {
  final String text;
  final String original;
  final bool isError;
  final bool isFinal;

  CaptionMessage({
    required this.text,
    required this.original,
    required this.isError,
    required this.isFinal,
  });

  factory CaptionMessage.fromJson(Map<String, dynamic> json) {
    return CaptionMessage(
      text: json['text'] ?? '',
      original: json['original'] ?? '',
      isError: json['type'] == 'error',
      isFinal: json['is_final'] ?? true,
    );
  }
}

class TranslationService {
  final String serverHost;
  final int serverPort;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _captionController = StreamController<CaptionMessage>.broadcast();

  // Auto-reconnect state
  bool _intentionallyStopped = false;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;

  // Last known settings so we can re-send start on reconnect
  String _sourceLang = 'auto';
  String _targetLang = 'en';
  bool _useMic = false;
  int? _inputDeviceIndex;
  int? _outputDeviceIndex;

  String get _wsUrl => 'ws://$serverHost:$serverPort/captions';

  TranslationService({required this.serverHost, this.serverPort = 8765});

  /// Stream of incoming caption messages from the server
  Stream<CaptionMessage> get captions => _captionController.stream;

  /// Connect to server WebSocket then send start command
  Future<void> start({
    String sourceLang = 'auto',
    String targetLang = 'en',
    bool useMic = false,
    int? inputDeviceIndex,
    int? outputDeviceIndex,
  }) async {
    _intentionallyStopped = false;
    _sourceLang = sourceLang;
    _targetLang = targetLang;
    _useMic = useMic;
    _inputDeviceIndex = inputDeviceIndex;
    _outputDeviceIndex = outputDeviceIndex;
    _reconnectAttempt = 0;
    await _connect();
  }

  Future<void> _connect() async {
    if (_intentionallyStopped) return;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));

      // Wait for the handshake to complete (throws if server is down)
      await _channel!.ready;

      // Connected — reset backoff
      _reconnectAttempt = 0;
      debugPrint('[WS] Connected to $_wsUrl');

      _sub = _channel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            _captionController.add(CaptionMessage.fromJson(json));
          } catch (_) {}
        },
        onDone: () {
          debugPrint('[WS] Connection closed.');
          if (!_intentionallyStopped) {
            _captionController.add(
              CaptionMessage(
                text: '⚠ Server disconnected. Reconnecting…',
                original: '',
                isError: true,
                isFinal: true,
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
              isError: true,
              isFinal: true,
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
      '[WS] Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempt)…',
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
  }) {
    _sourceLang = sourceLang;
    _targetLang = targetLang;
    _useMic = useMic;
    _inputDeviceIndex = inputDeviceIndex;
    _outputDeviceIndex = outputDeviceIndex;

    if (_channel != null) {
      final payload = <String, dynamic>{
        'cmd': 'settings_update',
        'source': sourceLang,
        'target': targetLang,
        'use_mic': useMic,
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

  /// Send stop command and close WebSocket (no auto-reconnect after this)
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

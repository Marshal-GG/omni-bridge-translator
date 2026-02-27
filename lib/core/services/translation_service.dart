// lib/core/services/translation_service.dart
//
// Connects to the Python WebSocket server (flutter_server.py) and
// streams live translated captions.
//
// Required pubspec.yaml dependencies (already present):
//   web_socket_channel: ^2.4.0
//   http: ^1.2.0
//
// Usage:
//   final service = TranslationService(serverHost: 'localhost', serverPort: 8765);
//   service.captions.listen((caption) => ...);
//   await service.start(sourceLang: 'auto', targetLang: 'en');
//   await service.stop();

import 'dart:async';
import 'dart:convert';
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
  final _captionController = StreamController<CaptionMessage>.broadcast();

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
    _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));

    _channel!.stream.listen(
      (data) {
        try {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          _captionController.add(CaptionMessage.fromJson(json));
        } catch (_) {}
      },
      onDone: () => _captionController.add(
        CaptionMessage(
          text: '[Disconnected]',
          original: '',
          isError: true,
          isFinal: true,
        ),
      ),
      onError: (e) => _captionController.add(
        CaptionMessage(
          text: '[Error: $e]',
          original: '',
          isError: true,
          isFinal: true,
        ),
      ),
    );

    // Send start command over WebSocket
    final startPayload = <String, dynamic>{
      'cmd': 'start',
      'source': sourceLang,
      'target': targetLang,
      'use_mic': useMic,
    };
    if (inputDeviceIndex != null) {
      startPayload['input_device_index'] = inputDeviceIndex;
    }
    if (outputDeviceIndex != null) {
      startPayload['output_device_index'] = outputDeviceIndex;
    }
    _channel!.sink.add(jsonEncode(startPayload));
  }

  /// Update active translation settings without reconnecting socket
  void updateSettings({
    required String sourceLang,
    required String targetLang,
    required bool useMic,
    int? inputDeviceIndex,
    int? outputDeviceIndex,
  }) {
    if (_channel != null) {
      final updatePayload = <String, dynamic>{
        'cmd': 'settings_update',
        'source': sourceLang,
        'target': targetLang,
        'use_mic': useMic,
      };
      if (inputDeviceIndex != null) {
        updatePayload['input_device_index'] = inputDeviceIndex;
      }
      if (outputDeviceIndex != null) {
        updatePayload['output_device_index'] = outputDeviceIndex;
      }
      _channel!.sink.add(jsonEncode(updatePayload));
    }
  }

  /// Send stop command and close WebSocket
  Future<void> stop() async {
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

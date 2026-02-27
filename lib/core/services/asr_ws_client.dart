import 'dart:convert';
import 'package:http/http.dart' as http;
import '../routes/routes_config.dart';
import 'asr_text_controller.dart';
import 'translation_service.dart';

/// Connects to the Python flutter_server.py via WebSocket,
/// sends the start command, and feeds translated captions to [asrTextController].
class AsrWebSocketClient {
  TranslationService? _service;

  void start({
    String sourceLang = 'auto',
    String targetLang = 'en',
    bool useMic = false,
    int? inputDeviceIndex,
    int? outputDeviceIndex,
  }) {
    const url = '127.0.0.1';
    const port = 8765;
    debugPrint('ASR WS connecting to: ws://$url:$port/captions');

    _service = TranslationService(serverHost: url, serverPort: port);

    _service!.captions.listen((msg) {
      if (msg.isError) {
        debugPrint('ASR error: ${msg.text}');
        asrTextController.updateInterim('Connection Issue: ${msg.text}');
        return;
      }
      final text = msg.text.trim();
      if (text.isEmpty) return;

      if (msg.isFinal) {
        asrTextController.commitFinal(text);
      } else {
        asrTextController.updateInterim(text);
      }
    });

    _service!.start(
      sourceLang: sourceLang,
      targetLang: targetLang,
      useMic: useMic,
      inputDeviceIndex: inputDeviceIndex,
      outputDeviceIndex: outputDeviceIndex,
    );
  }

  void updateSettings({
    required String sourceLang,
    required String targetLang,
    required bool useMic,
    int? inputDeviceIndex,
    int? outputDeviceIndex,
  }) {
    _service?.updateSettings(
      sourceLang: sourceLang,
      targetLang: targetLang,
      useMic: useMic,
      inputDeviceIndex: inputDeviceIndex,
      outputDeviceIndex: outputDeviceIndex,
    );
  }

  /// Fetches available audio input and output devices from the Python server.
  Future<Map<String, dynamic>> loadDevices() async {
    try {
      final response = await http
          .get(Uri.parse('http://127.0.0.1:8765/devices'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'input': List<Map<String, dynamic>>.from(data['input'] ?? []),
          'output': List<Map<String, dynamic>>.from(data['output'] ?? []),
          'default_input_name': data['default_input_name'] ?? 'Default',
          'default_output_name': data['default_output_name'] ?? 'Default',
        };
      }
    } catch (e) {
      debugPrint('Failed to load devices: $e');
    }
    return {
      'input': <Map<String, dynamic>>[],
      'output': <Map<String, dynamic>>[],
      'default_input_name': 'Default',
      'default_output_name': 'Default',
    };
  }

  void stop() {
    _service?.stop();
    _service = null;
  }
}

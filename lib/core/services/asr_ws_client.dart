import '../routes/routes_config.dart';
import 'asr_text_controller.dart';
import 'translation_service.dart';

/// Connects to the Python flutter_server.py via WebSocket,
/// sends the start command, and feeds translated captions to [asrTextController].
class AsrWebSocketClient {
  TranslationService? _service;

  void start({String sourceLang = 'auto', String targetLang = 'en'}) {
    const url = 'localhost';
    const port = 8765;
    debugPrint('ASR WS connecting to: ws://$url:$port/captions');

    _service = TranslationService(serverHost: url, serverPort: port);

    _service!.captions.listen((msg) {
      if (msg.isError) {
        debugPrint('ASR error: ${msg.text}');
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

    _service!.start(sourceLang: sourceLang, targetLang: targetLang);
  }

  void stop() {
    _service?.stop();
    _service = null;
  }
}

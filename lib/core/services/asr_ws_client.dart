import 'dart:convert';
import 'package:http/http.dart' as http;
import '../routes/routes_config.dart';
import 'asr_text_controller.dart';
import 'tracking_service.dart';
import 'translation_service.dart';
import '../../screens/translation/bloc/translation_bloc.dart';
import '../../screens/translation/bloc/translation_event.dart';

/// Connects to the Python flutter_server.py via WebSocket,
/// sends the start command, and feeds translated captions to [asrTextController].
class AsrWebSocketClient {
  TranslationService? _service;
  // Weak reference back to bloc so we can dispatch audio level events
  TranslationBloc? _bloc;

  void attachBloc(TranslationBloc bloc) => _bloc = bloc;

  Stream<CaptionMessage>? get captions => _service?.captions;

  void Function(double inputLevel, double outputLevel)? onAudioLevel;

  void start({
    String sourceLang = 'auto',
    String targetLang = 'en',
    bool useMic = false,
    int? inputDeviceIndex,
    int? outputDeviceIndex,
    String translationModel = 'google',
    String apiKey = '',
    String transcriptionModel = 'online',
  }) {
    const url = '127.0.0.1';
    const port = 8765;
    debugPrint('ASR WS connecting to: ws://$url:$port/captions');

    _service = TranslationService(serverHost: url, serverPort: port);

    _service!.captions.listen((msg) {
      // Audio level update — dispatch via callback
      if (msg.inputLevel != null || msg.outputLevel != null) {
        onAudioLevel?.call(msg.inputLevel ?? 0.0, msg.outputLevel ?? 0.0);
        return;
      }

      // Usage stats — log to Firestore
      if (msg.usageStats != null) {
        TrackingService.instance.logModelUsage(msg.usageStats!);
        return;
      }

      // Override signal from backend — handled by the UI layer, not shown in captions
      if (msg.sourceLangOverride != null) return;

      if (msg.isError) {
        final activeLang = _bloc?.state.activeSourceLang ?? 'unknown';
        final errMsg = msg.text.trim().isNotEmpty
            ? msg.text.trim()
            : 'The server returned an error while processing audio.';

        // Python Server errors will just show in the UI via the bloc event now

        _bloc?.add(
          LangErrorEvent(
            '⚠ Language error (source: $activeLang): $errMsg. '
            'Try a different source language in Settings.',
          ),
        );
        asrTextController.value = '[Error] $errMsg';
        return;
      }
      final text = msg.text.trim();
      if (text.isEmpty) return;

      if (msg.isFinal) {
        asrTextController.commitFinal(text);
        // Feed into history — msg.original is the transcription, text is translation
        final transcription = msg.original.trim().isNotEmpty
            ? msg.original.trim()
            : text;
        HistoryService.instance.addEntry(transcription, text);
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
      translationModel: translationModel,
      apiKey: apiKey,
      transcriptionModel: transcriptionModel,
    );
  }

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
    String transcriptionModel = 'online',
  }) {
    _service?.updateSettings(
      sourceLang: sourceLang,
      targetLang: targetLang,
      useMic: useMic,
      inputDeviceIndex: inputDeviceIndex,
      outputDeviceIndex: outputDeviceIndex,
      desktopVolume: desktopVolume,
      micVolume: micVolume,
      translationModel: translationModel,
      apiKey: apiKey,
      transcriptionModel: transcriptionModel,
    );
    // Keep HistoryService in sync with the current source/target lang
    HistoryService.instance.configure(
      sourceLang: sourceLang,
      targetLang: targetLang,
      translateFn: (text, src, tgt) async =>
          text, // placeholder; real fn passed by overlay
    );
  }

  /// Instantly update audio capture volumes without restarting the pipeline.
  void liveVolumeUpdate({
    required double desktopVolume,
    required double micVolume,
  }) {
    _service?.sendVolumeUpdate(
      desktopVolume: desktopVolume,
      micVolume: micVolume,
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

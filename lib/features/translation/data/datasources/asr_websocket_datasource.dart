import 'dart:convert';
import '../../domain/entities/caption_message.dart';
import 'package:http/http.dart' as http;
import 'package:omni_bridge/core/config/server_config.dart';
import 'package:omni_bridge/core/routes/routes_config.dart';
import 'package:omni_bridge/core/device/asr_text_controller.dart';
import 'package:omni_bridge/data/services/firebase/tracking_service.dart';
import 'package:omni_bridge/data/services/translation/translation_service.dart';
import 'package:omni_bridge/features/history/domain/usecases/add_history_entry_usecase.dart';
import 'package:omni_bridge/features/history/domain/usecases/configure_history_usecase.dart';

/// Connects to the Python flutter_server.py via WebSocket,
/// sends the start command, and feeds translated captions to [asrTextController].
///
/// The WebSocket connection is kept alive across toggle off→on cycles to avoid
/// the WASAPI cold-start delay on every toggle. Only [dispose] fully tears down
/// the connection (called on app shutdown).
class AsrWebSocketClient {
  TranslationService? _service;

  Stream<CaptionMessage>? get captions => _service?.captions;

  void Function(double inputLevel, double outputLevel)? onAudioLevel;

  final AddHistoryEntryUseCase addHistoryEntry;
  final ConfigureHistoryUseCase configureHistory;

  AsrWebSocketClient({
    required this.addHistoryEntry,
    required this.configureHistory,
  }) {
    _ensureService();
  }

  /// Creates the [TranslationService] and pre-connects the WebSocket
  /// so the connection is ready before the user presses play.
  void _ensureService() {
    if (_service != null) return;
    debugPrint('ASR WS pre-connecting to: ${ServerConfig.wsUrl}/captions');
    _service = TranslationService(serverHost: ServerConfig.host, serverPort: ServerConfig.port);

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

      // Override signal from backend — handled by the UI layer
      if (msg.sourceLangOverride != null) return;

      if (msg.isSystemMessage) {
        asrTextController.showSystemMessage(msg.text);
        return;
      }

      if (msg.isError) {
        final errMsg = msg.text.trim().isNotEmpty
            ? msg.text.trim()
            : 'The server returned an error while processing audio.';
        asrTextController.showSystemMessage('⚠ Error: $errMsg.');

        // Remote logging
        TrackingService.instance.logError('Server Error', errMsg);
        return;
      }

      final text = msg.text.trim();
      if (text.isEmpty) return;

      if (msg.isFinal) {
        asrTextController.commitFinal(text);
        final transcription = msg.original.trim().isNotEmpty
            ? msg.original.trim()
            : text;
        addHistoryEntry(transcription, text);
      } else {
        asrTextController.updateInterim(text);
      }
    });

    // Pre-connect after a short delay so the server has time to settle.
    // Fire-and-forget — does not block UI startup.
    Future.delayed(const Duration(milliseconds: 500), _service!.preConnect);
  }

  void start({
    String sourceLang = 'auto',
    String targetLang = 'en',
    bool useMic = false,
    int? inputDeviceIndex,
    int? outputDeviceIndex,
    String translationModel = 'google',
    String apiKey = '',
    String googleCredentialsJson = '',
    String transcriptionModel = 'online',
  }) {
    // Reuse the existing service + connection if already live.
    // This avoids the WebSocket handshake + WASAPI cold-start on every toggle.
    _ensureService();

    _service!.start(
      sourceLang: sourceLang,
      targetLang: targetLang,
      useMic: useMic,
      inputDeviceIndex: inputDeviceIndex,
      outputDeviceIndex: outputDeviceIndex,
      translationModel: translationModel,
      apiKey: apiKey,
      googleCredentialsJson: googleCredentialsJson,
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
    String googleCredentialsJson = '',
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
      googleCredentialsJson: googleCredentialsJson,
      transcriptionModel: transcriptionModel,
    );
    configureHistory(
      sourceLang: sourceLang,
      targetLang: targetLang,
      translateFn: (text, src, tgt) async => text,
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
          .get(Uri.parse('${ServerConfig.httpUrl}/devices'))
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

  /// Soft-stop: tells the server to pause audio capture but keeps the WebSocket
  /// open. The next [start] call skips the handshake and fires immediately.
  void stop() {
    _service?.sendStopCommand();
  }

  /// Hard-stop: fully tears down the WebSocket. Only call on app shutdown.
  Future<void> dispose() async {
    await _service?.stop();
    _service = null;
  }
}

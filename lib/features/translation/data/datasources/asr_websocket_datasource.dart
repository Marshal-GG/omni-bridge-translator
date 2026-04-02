import 'dart:async';
import 'dart:convert';
import '../../domain/entities/caption_message.dart';
import 'package:http/http.dart' as http;
import 'package:omni_bridge/core/config/server_config.dart';
import 'package:omni_bridge/core/device/asr_text_controller.dart';
import 'package:omni_bridge/core/data/datasources/usage_metrics_remote_datasource.dart';
import 'package:omni_bridge/core/utils/app_logger.dart';
import 'package:omni_bridge/core/data/interfaces/resettable.dart';
import './translation_websocket_client.dart';
import 'package:omni_bridge/features/history/domain/usecases/add_history_entry_usecase.dart';
import 'package:omni_bridge/features/history/domain/usecases/configure_history_usecase.dart';

/// Connects to the Python flutter_server.py via WebSocket,
/// sends the start command, and feeds translated captions to [asrTextController].
///
/// The WebSocket connection is kept alive across toggle off→on cycles to avoid
/// the WASAPI cold-start delay on every toggle. Only [dispose] fully tears down
/// the connection (called on app shutdown).
class AsrWebSocketClient implements IResettable {
  static const String _tag = 'AsrWebSocketClient';
  TranslationWebsocketClient? _service;

  Stream<CaptionMessage>? get captions => _service?.captions;

  final _audioLevelController =
      StreamController<(double, double)>.broadcast();

  Stream<(double, double)> get audioLevelStream => _audioLevelController.stream;

  final AddHistoryEntryUseCase addHistoryEntry;
  final ConfigureHistoryUseCase configureHistory;

  AsrWebSocketClient({
    required this.addHistoryEntry,
    required this.configureHistory,
  }) {
    _ensureService();
  }

  /// Creates the [TranslationWebsocketClient] and pre-connects the WebSocket
  /// so the connection is ready before the user presses play.
  void _ensureService() {
    if (_service != null) return;
    AppLogger.d(
      'ASR WS pre-connecting to: ${ServerConfig.wsUrl}/captions',
      tag: _tag,
    );
    _service = TranslationWebsocketClient(
      serverHost: ServerConfig.host,
      serverPort: ServerConfig.port,
    );

    _service!.captions.listen((msg) {
      // Audio level update — dispatch via callback
      if (msg.inputLevel != null || msg.outputLevel != null) {
        _audioLevelController.add(
          (msg.inputLevel ?? 0.0, msg.outputLevel ?? 0.0),
        );
        return;
      }

      // Usage stats — log to Firestore
      if (msg.usageStats != null) {
        UsageMetricsRemoteDataSource.instance.logModelUsage(msg.usageStats!);
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
        UsageMetricsRemoteDataSource.instance.logEvent('Server Error', {
          'error': errMsg,
        });
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
    String nvidiaNimKey = '',
    dynamic googleCredentials = '',
    String transcriptionModel = 'online',
    String rivaTranslationFunctionId = '',
    String rivaAsrParakeetFunctionId = '',
    String rivaAsrCanaryFunctionId = '',
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
      nvidiaNimKey: nvidiaNimKey,
      googleCredentials: googleCredentials,
      transcriptionModel: transcriptionModel,
      rivaTranslationFunctionId: rivaTranslationFunctionId,
      rivaAsrParakeetFunctionId: rivaAsrParakeetFunctionId,
      rivaAsrCanaryFunctionId: rivaAsrCanaryFunctionId,
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
    String nvidiaNimKey = '',
    dynamic googleCredentials = '',
    String transcriptionModel = 'online',
    String rivaTranslationFunctionId = '',
    String rivaAsrParakeetFunctionId = '',
    String rivaAsrCanaryFunctionId = '',
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
      nvidiaNimKey: nvidiaNimKey,
      googleCredentials: googleCredentials,
      transcriptionModel: transcriptionModel,
      rivaTranslationFunctionId: rivaTranslationFunctionId,
      rivaAsrParakeetFunctionId: rivaAsrParakeetFunctionId,
      rivaAsrCanaryFunctionId: rivaAsrCanaryFunctionId,
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

  /// Instantly update active capture devices without restarting the pipeline.
  void liveDeviceUpdate({int? inputDeviceIndex, int? outputDeviceIndex}) {
    _service?.sendDeviceUpdate(
      inputDeviceIndex: inputDeviceIndex,
      outputDeviceIndex: outputDeviceIndex,
    );
  }

  /// Instantly toggle microphone status for live level preview.
  void liveMicToggle(bool useMic) {
    _service?.sendMicToggle(useMic);
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
      AppLogger.e('Failed to load devices', tag: _tag, error: e);
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
  Future<void> stop() async {
    _service?.sendStopCommand();
  }

  /// Standard reset from IResettable. Fully clears WebSocket state.
  /// Called on user logout to prevent state/errors from leaking between sessions.
  @override
  void reset() {
    AppLogger.i('Resetting ASR WebSocket state...', tag: _tag);
    _service?.sendResetSessionCommand();
    _service?.stop();
    _service = null;
  }

  /// Hard-stop: fully tears down the WebSocket. Only call on app shutdown.
  Future<void> dispose() async {
    await _service?.stop();
    _service = null;
    await _audioLevelController.close();
  }
}

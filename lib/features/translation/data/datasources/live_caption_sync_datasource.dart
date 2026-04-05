import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:omni_bridge/core/constants/firebase_paths.dart';
import 'package:omni_bridge/core/utils/app_logger.dart';
import 'package:omni_bridge/core/network/rtdb_client.dart';
import 'package:omni_bridge/core/data/datasources/session_remote_datasource.dart';
import 'package:omni_bridge/core/data/interfaces/resettable.dart';

abstract class ILiveCaptionSyncDataSource implements IResettable {
  Future<void> syncLiveCaption(
    String originalText,
    String translatedText,
    String sourceLang,
    String targetLang,
    bool isFinal,
    String translationModel,
  );
  void dispose();
}

class LiveCaptionSyncDataSource implements ILiveCaptionSyncDataSource {
  LiveCaptionSyncDataSource._();
  static final LiveCaptionSyncDataSource instance =
      LiveCaptionSyncDataSource._();

  static const String _tag = 'LiveCaptionSyncDataSource';

  final RTDBClient _rtdbClient = RTDBClient.instance;

  // Sync control for high-frequency captions
  bool _isSyncingInterim = false;
  Map<String, dynamic>? _pendingInterim;
  int _lastCaptionTimestamp = 0;

  @override
  Future<void> syncLiveCaption(
    String originalText,
    String translatedText,
    String sourceLang,
    String targetLang,
    bool isFinal,
    String translationModel,
  ) async {
    final uid = _rtdbClient.uid;
    if (uid == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final currentSessionId =
        SessionRemoteDataSource.instance.currentSessionId ?? 'unknown';

    try {
      if (isFinal) {
        // 1. Permanent Log (Append)
        final url = await _rtdbClient.getRTDBUrl(FirebasePaths.captions);
        if (url != null) {
          await _rtdbClient.request(
            (client) => client.post(
              url,
              body: jsonEncode({
                'originalText': originalText,
                'translatedText': translatedText,
                'sourceLang': sourceLang,
                'targetLang': targetLang,
                'translationModel': translationModel,
                'isFinal': true,
                'timestamp': {'.sv': 'timestamp'},
                'sessionId': currentSessionId,
              }),
            ),
            context: 'syncLiveCaption:Final',
          );
        }
        // 2. Clear interim node
        final interimUrl = await _rtdbClient.getRTDBUrl(
          FirebasePaths.currentCaption,
        );
        if (interimUrl != null) {
          // Fire and forget delete so we don't block
          unawaited(http.delete(interimUrl).catchError((_) => http.Response('', 500)));
        }

        _lastCaptionTimestamp = now;
        _pendingInterim = null;
      } else {
        if (now < _lastCaptionTimestamp) return;

        final data = {
          'originalText': originalText,
          'translatedText': translatedText,
          'sourceLang': sourceLang,
          'targetLang': targetLang,
          'translationModel': translationModel,
          'isFinal': false,
          'timestamp': {'.sv': 'timestamp'},
          'sessionId': currentSessionId,
        };

        if (_isSyncingInterim) {
          _pendingInterim = data;
          return;
        }

        await _syncInterimSequentially(data);
      }
    } catch (e) {
      AppLogger.e('Error pushing live caption to RTDB', tag: _tag, error: e);
    }
  }

  Future<void> _syncInterimSequentially(Map<String, dynamic> data) async {
    _isSyncingInterim = true;
    _pendingInterim = null;

    try {
      final url = await _rtdbClient.getRTDBUrl(FirebasePaths.currentCaption);
      if (url != null) {
        await _rtdbClient.request(
          (client) => client.put(url, body: jsonEncode(data)),
          context: 'syncLiveCaption:Interim',
          maxRetries: 1,
        );
      }
    } finally {
      _isSyncingInterim = false;
      if (_pendingInterim != null) {
        final nextData = _pendingInterim!;
        _pendingInterim = null;
        unawaited(_syncInterimSequentially(nextData));
      }
    }
  }

  @override
  void reset() {
    AppLogger.i('Resetting LiveCaptionSync state...', tag: _tag);
    _pendingInterim = null;
    _isSyncingInterim = false;
    _lastCaptionTimestamp = 0;
  }

  @override
  void dispose() {
    _pendingInterim = null;
    AppLogger.d('Disposed', tag: _tag);
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:omni_bridge/core/config/server_config.dart';

/// Communicates with the Python server's translation/model management endpoints.
class TranslationRestDatasource {
  static String get _base => ServerConfig.httpUrl;
  static const _timeout = Duration(seconds: 10);

  /// Returns current model status for a specific size:
  /// { downloaded: bool, size_mb: double, progress: double, status: String }
  Future<Map<String, dynamic>> getStatus(String size) async {
    try {
      final resp = await http
          .get(Uri.parse('$_base/whisper/status?size=$size'))
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[TranslationRestDatasource] getStatus error: $e');
    }
    return {
      'downloaded': false,
      'size_mb': 0.0,
      'progress': 0.0,
      'status': 'idle',
    };
  }

  /// Starts the model download (no-op if already downloaded).
  Future<Map<String, dynamic>> startDownload(String size) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$_base/whisper/download'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'size': size}),
          )
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[TranslationRestDatasource] startDownload error: $e');
    }
    return {'status': 'error'};
  }

  /// Polls download progress for a specific size.
  Future<Map<String, dynamic>> getProgress(String size) async {
    try {
      final resp = await http
          .get(Uri.parse('$_base/whisper/progress?size=$size'))
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[TranslationRestDatasource] getProgress error: $e');
    }
    return {'downloaded': false, 'progress': 0.0, 'status': 'idle'};
  }

  /// Deletes the cached model.
  Future<bool> deleteModel(String size) async {
    try {
      final resp = await http
          .delete(Uri.parse('$_base/whisper/model?size=$size'))
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data['status'] == 'deleted';
      }
    } catch (e) {
      debugPrint('[TranslationRestDatasource] deleteModel error: $e');
    }
    return false;
  }

  /// Returns aggregated status for all models (Whisper, Riva, Llama, etc.)
  Future<List<dynamic>> getModelStatuses() async {
    try {
      final resp = await http
          .get(Uri.parse('$_base/models/status'))
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data['models'] as List<dynamic>;
      }
    } catch (e) {
      // ignore: avoid_print
      print('TranslationRestDatasource.getModelStatuses error: $e');
    }
    return [];
  }

  /// Explicitly unloads the Whisper model from memory.
  Future<bool> unloadModel() async {
    try {
      final resp = await http
          .post(Uri.parse('$_base/whisper/unload'))
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data['status'] == 'unloaded';
      }
    } catch (e) {
      debugPrint('[TranslationRestDatasource] unloadModel error: $e');
    }
    return false;
  }
}

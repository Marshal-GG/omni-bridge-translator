import 'dart:convert';
import 'package:http/http.dart' as http;

/// Communicates with the Python server's Whisper model management endpoints.
class WhisperService {
  static const _base = 'http://127.0.0.1:8765';
  static const _timeout = Duration(seconds: 10);

  /// Returns current model status:
  /// { downloaded: bool, size_mb: double, progress: double, status: String }
  Future<Map<String, dynamic>> getStatus() async {
    try {
      final resp = await http
          .get(Uri.parse('$_base/whisper/status'))
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {
      'downloaded': false,
      'size_mb': 0.0,
      'progress': 0.0,
      'status': 'idle',
    };
  }

  /// Starts the model download (no-op if already downloaded).
  Future<Map<String, dynamic>> startDownload() async {
    try {
      final resp = await http
          .post(Uri.parse('$_base/whisper/download'))
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {'status': 'error'};
  }

  /// Polls download progress.
  Future<Map<String, dynamic>> getProgress() async {
    try {
      final resp = await http
          .get(Uri.parse('$_base/whisper/progress'))
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {'downloaded': false, 'progress': 0.0, 'status': 'idle'};
  }

  /// Deletes the cached model.
  Future<bool> deleteModel() async {
    try {
      final resp = await http
          .delete(Uri.parse('$_base/whisper/model'))
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data['status'] == 'deleted';
      }
    } catch (_) {}
    return false;
  }
}

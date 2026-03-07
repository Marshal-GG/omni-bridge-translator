import 'dart:convert';
import 'package:http/http.dart' as http;

/// Communicates with the Python server's Whisper model management endpoints.
class WhisperService {
  static const _base = 'http://127.0.0.1:8765';
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
    } catch (_) {}
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
    } catch (_) {}
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
    } catch (_) {}
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
    } catch (_) {}
    return false;
  }
}

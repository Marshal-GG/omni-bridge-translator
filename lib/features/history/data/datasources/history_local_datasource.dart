import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:omni_bridge/features/history/domain/entities/history_entry.dart';

/// Collects live transcription + translation pairs into two buckets:
///  - [liveEntries]: every final transcript (one per utterance)
///  - [chunkedEntries]: 5-second re-translations (longer context, cleaner output)
class HistoryLocalDataSource {
  HistoryLocalDataSource();

  final ValueNotifier<List<HistoryEntry>> liveEntries = ValueNotifier([]);
  final ValueNotifier<List<HistoryEntry>> chunkedEntries = ValueNotifier([]);

  final List<String> _chunkBuffer = [];
  Timer? _chunkTimer;

  String _sourceLang = 'auto';
  String _targetLang = 'en';

  // Callback for re-translating a 5-sec chunk (wired by the overlay)
  Future<String> Function(String text, String src, String tgt)? _translateFn;

  void configure({
    required String sourceLang,
    required String targetLang,
    required Future<String> Function(String text, String src, String tgt)
    translateFn,
  }) {
    _sourceLang = sourceLang;
    _targetLang = targetLang;
    _translateFn = translateFn;
    _restartChunkTimer();
  }

  /// Called for every final transcript/translation pair.
  void addEntry(String transcription, String translation) {
    final entry = HistoryEntry(
      transcription: transcription,
      translation: translation,
      timestamp: DateTime.now(),
      sourceLang: _sourceLang,
      targetLang: _targetLang,
    );
    liveEntries.value = [...liveEntries.value, entry];
    _chunkBuffer.add(transcription);
  }

  void _restartChunkTimer() {
    _chunkTimer?.cancel();
    _chunkTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_chunkBuffer.isEmpty) return;
      final combined = _chunkBuffer.join(' ');
      _chunkBuffer.clear();

      final translation = _translateFn != null
          ? await _translateFn!(combined, _sourceLang, _targetLang)
          : combined;

      final entry = HistoryEntry(
        transcription: combined,
        translation: translation,
        timestamp: DateTime.now(),
        sourceLang: _sourceLang,
        targetLang: _targetLang,
      );
      chunkedEntries.value = [...chunkedEntries.value, entry];
    });
  }

  void clear() {
    liveEntries.value = [];
    chunkedEntries.value = [];
    _chunkBuffer.clear();
  }

  void dispose() {
    _chunkTimer?.cancel();
  }
}

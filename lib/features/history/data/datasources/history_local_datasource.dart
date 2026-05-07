import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:omni_bridge/core/data/interfaces/resettable.dart';
import 'package:omni_bridge/features/history/domain/entities/history_entry.dart';

/// Collects live transcription + translation pairs into two buckets:
///  - [liveEntries]: every final transcript (one per utterance)
///  - [chunkedEntries]: 5-second re-translations (longer context, cleaner output)
class HistoryLocalDataSource implements IResettable {
  HistoryLocalDataSource();

  final ValueNotifier<List<HistoryEntry>> liveEntries = ValueNotifier([]);
  final ValueNotifier<List<HistoryEntry>> chunkedEntries = ValueNotifier([]);

  final List<String> _chunkBuffer = [];
  Timer? _chunkTimer;

  String _sourceLang = 'auto';
  String _targetLang = 'en';

  // Callback for re-translating a 5-sec chunk (wired by the overlay)
  Future<String> Function(String text, String src, String tgt)? _translateFn;

  /// Returns the active translation engine ID at the time of capture. Wired
  /// by the Translation feature's `configureHistory` call so the History
  /// feature stays free of cross-feature imports.
  String? Function()? _activeEngineProvider;

  void configure({
    required String sourceLang,
    required String targetLang,
    required Future<String> Function(String text, String src, String tgt)
    translateFn,
    String? Function()? activeEngineProvider,
  }) {
    _sourceLang = sourceLang;
    _targetLang = targetLang;
    _translateFn = translateFn;
    _activeEngineProvider = activeEngineProvider;
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
      engine: _activeEngineProvider?.call(),
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
        engine: _activeEngineProvider?.call(),
      );
      chunkedEntries.value = [...chunkedEntries.value, entry];
    });
  }

  void clear() {
    liveEntries.value = [];
    chunkedEntries.value = [];
    _chunkBuffer.clear();
  }

  /// Removes a single entry from whichever stream it currently lives in.
  /// Compares by reference identity — entries are only ever appended to the
  /// notifier, so the same instance the UI holds is the one we drop.
  void removeEntry(HistoryEntry entry) {
    final live = liveEntries.value;
    if (live.contains(entry)) {
      liveEntries.value = live.where((e) => !identical(e, entry)).toList();
      return;
    }
    final chunked = chunkedEntries.value;
    if (chunked.contains(entry)) {
      chunkedEntries.value =
          chunked.where((e) => !identical(e, entry)).toList();
    }
  }

  @override
  void reset() {
    clear();
    _chunkTimer?.cancel();
    _chunkTimer = null;
  }

  void dispose() {
    reset();
  }
}

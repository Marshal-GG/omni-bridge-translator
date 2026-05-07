import 'package:flutter/foundation.dart';
import '../entities/history_entry.dart';

abstract class IHistoryRepository {
  ValueListenable<List<HistoryEntry>> get liveEntries;
  ValueListenable<List<HistoryEntry>> get chunkedEntries;

  void addEntry(String transcription, String translation);

  void removeEntry(HistoryEntry entry);

  void clear();

  void configure({
    required String sourceLang,
    required String targetLang,
    required Future<String> Function(String text, String src, String tgt)
    translateFn,
    String? Function()? activeEngineProvider,
  });

  void dispose();
}

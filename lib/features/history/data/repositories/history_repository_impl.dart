import 'package:flutter/foundation.dart';
import '../../domain/entities/history_entry.dart';
import '../../domain/repositories/i_history_repository.dart';
import '../datasources/history_local_datasource.dart';

class HistoryRepositoryImpl implements IHistoryRepository {
  final HistoryLocalDataSource localDataSource;

  HistoryRepositoryImpl({required this.localDataSource});

  @override
  ValueListenable<List<HistoryEntry>> get liveEntries =>
      localDataSource.liveEntries;

  @override
  ValueListenable<List<HistoryEntry>> get chunkedEntries =>
      localDataSource.chunkedEntries;

  @override
  void addEntry(String transcription, String translation) {
    localDataSource.addEntry(transcription, translation);
  }

  @override
  void clear() {
    localDataSource.clear();
  }

  @override
  void configure({
    required String sourceLang,
    required String targetLang,
    required Future<String> Function(String text, String src, String tgt)
    translateFn,
  }) {
    localDataSource.configure(
      sourceLang: sourceLang,
      targetLang: targetLang,
      translateFn: translateFn,
    );
  }

  @override
  void dispose() {
    localDataSource.dispose();
  }
}

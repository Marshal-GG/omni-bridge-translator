import 'package:flutter/foundation.dart';
import '../entities/history_entry.dart';
import '../repositories/i_history_repository.dart';

class GetChunkedHistoryUseCase {
  final IHistoryRepository repository;

  GetChunkedHistoryUseCase({required this.repository});

  ValueListenable<List<HistoryEntry>> call() {
    return repository.chunkedEntries;
  }
}

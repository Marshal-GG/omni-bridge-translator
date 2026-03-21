import '../repositories/i_history_repository.dart';

class AddHistoryEntryUseCase {
  final IHistoryRepository repository;

  AddHistoryEntryUseCase({required this.repository});

  void call(String transcription, String translation) {
    repository.addEntry(transcription, translation);
  }
}

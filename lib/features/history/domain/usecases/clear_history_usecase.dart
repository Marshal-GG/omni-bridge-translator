import '../repositories/i_history_repository.dart';

class ClearHistoryUseCase {
  final IHistoryRepository repository;

  ClearHistoryUseCase({required this.repository});

  void call() {
    repository.clear();
  }
}

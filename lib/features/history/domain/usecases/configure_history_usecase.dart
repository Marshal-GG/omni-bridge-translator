import '../repositories/i_history_repository.dart';

class ConfigureHistoryUseCase {
  final IHistoryRepository repository;

  ConfigureHistoryUseCase({required this.repository});

  void call({
    required String sourceLang,
    required String targetLang,
    required Future<String> Function(String text, String src, String tgt)
    translateFn,
  }) {
    repository.configure(
      sourceLang: sourceLang,
      targetLang: targetLang,
      translateFn: translateFn,
    );
  }
}

import '../repositories/i_startup_repository.dart';

class RunStartupSequenceUseCase {
  final IStartupRepository _repository;

  RunStartupSequenceUseCase(this._repository);

  Future<void> call() => _repository.initializeServices();
}

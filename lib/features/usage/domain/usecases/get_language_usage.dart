import 'package:omni_bridge/features/usage/domain/entities/language_usage.dart';
import 'package:omni_bridge/features/usage/domain/repositories/usage_repository.dart';

class GetLanguageUsage {
  final UsageRepository _repository;

  GetLanguageUsage(this._repository);

  Future<List<LanguageUsage>> call() => _repository.getLanguageUsage();
}

import 'package:omni_bridge/features/usage/domain/repositories/usage_repository.dart';

class ClearUsageCache {
  final UsageRepository _repository;
  ClearUsageCache(this._repository);
  void call() => _repository.clearCache();
}

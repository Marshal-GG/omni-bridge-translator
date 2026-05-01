import '../datasources/startup_remote_datasource.dart';
import '../../domain/repositories/i_startup_repository.dart';

class StartupRepositoryImpl implements IStartupRepository {
  final StartupRemoteDataSource _dataSource;

  StartupRepositoryImpl(this._dataSource);

  @override
  Future<void> initializeServices() => _dataSource.initializeServices();
}

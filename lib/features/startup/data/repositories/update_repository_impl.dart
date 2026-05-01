import '../datasources/update_remote_datasource.dart';
import '../../domain/entities/update_info.dart';
import '../../domain/repositories/i_update_repository.dart';

class UpdateRepositoryImpl implements IUpdateRepository {
  final UpdateRemoteDataSource _dataSource;

  UpdateRepositoryImpl(this._dataSource);

  @override
  Future<UpdateInfo> checkForUpdate() => _dataSource.checkForUpdate();
}

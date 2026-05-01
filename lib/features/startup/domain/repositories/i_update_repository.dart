import '../entities/update_info.dart';

abstract class IUpdateRepository {
  Future<UpdateInfo> checkForUpdate();
}

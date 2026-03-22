import '../entities/update_result.dart';

abstract class IUpdateRepository {
  Future<UpdateResult> checkForUpdate();
}

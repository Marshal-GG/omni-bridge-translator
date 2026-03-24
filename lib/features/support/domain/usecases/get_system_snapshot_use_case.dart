import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/system_snapshot.dart';
import '../repositories/i_support_repository.dart';

class GetSystemSnapshotUseCase {
  final ISupportRepository repository;

  GetSystemSnapshotUseCase(this.repository);

  Future<Either<Failure, SystemSnapshot>> call() async {
    return await repository.getSystemSnapshot();
  }
}

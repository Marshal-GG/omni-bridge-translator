import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/support_link.dart';
import '../repositories/i_support_repository.dart';

class GetSupportLinksUseCase {
  final ISupportRepository repository;

  GetSupportLinksUseCase(this.repository);

  Future<Either<Failure, List<SupportLink>>> call() async {
    return await repository.getSupportLinks();
  }
}

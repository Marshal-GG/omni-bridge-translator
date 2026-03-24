import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/support_message.dart';
import '../repositories/i_support_repository.dart';

class GetTicketMessagesUseCase {
  final ISupportRepository repository;

  GetTicketMessagesUseCase(this.repository);

  Stream<Either<Failure, List<SupportMessage>>> call(String ticketId) {
    return repository.getTicketMessages(ticketId);
  }
}

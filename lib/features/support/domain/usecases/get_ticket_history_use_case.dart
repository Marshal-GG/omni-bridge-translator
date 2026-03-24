import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/feedback_ticket.dart';
import '../repositories/i_support_repository.dart';

class GetTicketHistoryUseCase {
  final ISupportRepository repository;

  GetTicketHistoryUseCase(this.repository);

  Future<Either<Failure, List<FeedbackTicket>>> call() async {
    return await repository.getTicketHistory();
  }
}

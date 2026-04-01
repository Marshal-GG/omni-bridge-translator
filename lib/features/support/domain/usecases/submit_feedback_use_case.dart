import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/feedback_ticket.dart';
import '../repositories/i_support_repository.dart';

class SubmitFeedbackUseCase {
  final ISupportRepository repository;

  SubmitFeedbackUseCase(this.repository);

  Future<Either<Failure, Unit>> call(
    FeedbackTicket ticket,
    List<File> attachments,
  ) async {
    return await repository.submitFeedback(ticket, attachments);
  }
}

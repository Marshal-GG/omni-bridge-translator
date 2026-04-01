import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/support_link.dart';
import '../entities/feedback_ticket.dart';
import '../entities/system_snapshot.dart';
import '../entities/support_message.dart';

abstract class ISupportRepository {
  Future<Either<Failure, List<SupportLink>>> getSupportLinks();
  Future<Either<Failure, SystemSnapshot>> getSystemSnapshot();
  Future<Either<Failure, Unit>> submitFeedback(
    FeedbackTicket ticket,
    List<File> attachments,
  );
  Future<Either<Failure, List<FeedbackTicket>>> getTicketHistory();
  Stream<Either<Failure, List<SupportMessage>>> getTicketMessages(
    String ticketId,
  );
  Future<Either<Failure, Unit>> sendSupportMessage(
    String ticketId,
    SupportMessage message, {
    List<File> attachments = const [],
  });
}

import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/support_message.dart';
import '../repositories/i_support_repository.dart';

class SendSupportMessageUseCase {
  final ISupportRepository repository;

  SendSupportMessageUseCase(this.repository);

  Future<Either<Failure, Unit>> call(String ticketId, SupportMessage message, {List<File> attachments = const []}) async {
    return await repository.sendSupportMessage(ticketId, message, attachments: attachments);
  }
}

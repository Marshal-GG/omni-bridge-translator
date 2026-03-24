part of 'support_bloc.dart';

abstract class SupportEvent extends Equatable {
  const SupportEvent();

  @override
  List<Object?> get props => [];
}

class LoadSupportLinks extends SupportEvent {
  const LoadSupportLinks();
}

class CaptureSystemSnapshot extends SupportEvent {
  const CaptureSystemSnapshot();
}

class UpdateFeedbackType extends SupportEvent {
  final FeedbackType type;
  const UpdateFeedbackType(this.type);

  @override
  List<Object?> get props => [type];
}

class UpdateFeedbackSubject extends SupportEvent {
  final String subject;
  const UpdateFeedbackSubject(this.subject);

  @override
  List<Object?> get props => [subject];
}

class UpdateFeedbackMessage extends SupportEvent {
  final String message;
  const UpdateFeedbackMessage(this.message);

  @override
  List<Object?> get props => [message];
}

class AddAttachment extends SupportEvent {
  final File file;
  const AddAttachment(this.file);

  @override
  List<Object?> get props => [file];
}

class RemoveAttachment extends SupportEvent {
  final int index;
  const RemoveAttachment(this.index);

  @override
  List<Object?> get props => [index];
}

class SubmitFeedback extends SupportEvent {
  const SubmitFeedback();
}

class LoadTicketHistory extends SupportEvent {
  const LoadTicketHistory();
}

class OpenChat extends SupportEvent {
  final String ticketId;
  const OpenChat(this.ticketId);

  @override
  List<Object?> get props => [ticketId];
}

class AddChatAttachment extends SupportEvent {
  final File file;
  const AddChatAttachment(this.file);

  @override
  List<Object?> get props => [file];
}

class RemoveChatAttachment extends SupportEvent {
  final int index;
  const RemoveChatAttachment(this.index);

  @override
  List<Object?> get props => [index];
}

class SendMessage extends SupportEvent {
  final String text;
  final List<File> attachments;
  const SendMessage({required this.text, this.attachments = const []});

  @override
  List<Object?> get props => [text, attachments];
}

class UpdateChatMessages extends SupportEvent {
  final List<SupportMessage> messages;
  const UpdateChatMessages(this.messages);

  @override
  List<Object?> get props => [messages];
}

class CloseChat extends SupportEvent {
  const CloseChat();
}

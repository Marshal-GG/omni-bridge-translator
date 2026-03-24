part of 'support_bloc.dart';

class SupportState extends Equatable {
  final List<SupportLink> supportLinks;
  final bool isLoadingLinks;
  final SystemSnapshot? systemSnapshot;
  final FeedbackType feedbackType;
  final String subject;
  final String message;
  final List<File> attachments;
  final List<File> chatAttachments;
  final bool isSubmitting;
  final bool isSubmitted;
  final String? error;

  // Ticket History & Chat
  final List<FeedbackTicket> tickets;
  final bool isLoadingHistory;
  final String? activeTicketId;
  final List<SupportMessage> messages;
  final bool isLoadingMessages;
  final bool isSendingMessage;

  const SupportState({
    this.supportLinks = const [],
    this.isLoadingLinks = false,
    this.systemSnapshot,
    this.feedbackType = FeedbackType.bug,
    this.subject = '',
    this.message = '',
    this.attachments = const [],
    this.chatAttachments = const [],
    this.isSubmitting = false,
    this.isSubmitted = false,
    this.error,
    this.tickets = const [],
    this.isLoadingHistory = false,
    this.activeTicketId,
    this.messages = const [],
    this.isLoadingMessages = false,
    this.isSendingMessage = false,
  });

  SupportState copyWith({
    List<SupportLink>? supportLinks,
    bool? isLoadingLinks,
    SystemSnapshot? systemSnapshot,
    FeedbackType? feedbackType,
    String? subject,
    String? message,
    List<File>? attachments,
    List<File>? chatAttachments,
    bool? isSubmitting,
    bool? isSubmitted,
    String? error,
    List<FeedbackTicket>? tickets,
    bool? isLoadingHistory,
    String? activeTicketId,
    List<SupportMessage>? messages,
    bool? isLoadingMessages,
    bool? isSendingMessage,
  }) {
    return SupportState(
      supportLinks: supportLinks ?? this.supportLinks,
      isLoadingLinks: isLoadingLinks ?? this.isLoadingLinks,
      systemSnapshot: systemSnapshot ?? this.systemSnapshot,
      feedbackType: feedbackType ?? this.feedbackType,
      subject: subject ?? this.subject,
      message: message ?? this.message,
      attachments: attachments ?? this.attachments,
      chatAttachments: chatAttachments ?? this.chatAttachments,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSubmitted: isSubmitted ?? this.isSubmitted,
      error: error,
      tickets: tickets ?? this.tickets,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      activeTicketId: activeTicketId ?? this.activeTicketId,
      messages: messages ?? this.messages,
      isLoadingMessages: isLoadingMessages ?? this.isLoadingMessages,
      isSendingMessage: isSendingMessage ?? this.isSendingMessage,
    );
  }

  @override
  List<Object?> get props => [
        supportLinks,
        isLoadingLinks,
        systemSnapshot,
        feedbackType,
        subject,
        message,
        attachments,
        chatAttachments,
        isSubmitting,
        isSubmitted,
        error,
        tickets,
        isLoadingHistory,
        activeTicketId,
        messages,
        isLoadingMessages,
        isSendingMessage,
      ];
}

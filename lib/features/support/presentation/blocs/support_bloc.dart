import 'dart:async';
import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/feedback_ticket.dart';
import '../../domain/entities/support_link.dart';
import '../../domain/entities/system_snapshot.dart';
import '../../domain/entities/support_message.dart';
import '../../domain/usecases/get_support_links_use_case.dart';
import '../../domain/usecases/get_system_snapshot_use_case.dart';
import '../../domain/usecases/submit_feedback_use_case.dart';
import '../../domain/usecases/get_ticket_history_use_case.dart';
import '../../domain/usecases/get_ticket_messages_use_case.dart';
import '../../domain/usecases/send_support_message_use_case.dart';

part 'support_event.dart';
part 'support_state.dart';

class SupportBloc extends Bloc<SupportEvent, SupportState> {
  final GetSupportLinksUseCase getSupportLinks;
  final GetSystemSnapshotUseCase getSystemSnapshot;
  final SubmitFeedbackUseCase submitFeedback;
  final GetTicketHistoryUseCase getTicketHistory;
  final GetTicketMessagesUseCase getTicketMessages;
  final SendSupportMessageUseCase sendSupportMessage;

  StreamSubscription? _messagesSubscription;

  SupportBloc({
    required this.getSupportLinks,
    required this.getSystemSnapshot,
    required this.submitFeedback,
    required this.getTicketHistory,
    required this.getTicketMessages,
    required this.sendSupportMessage,
  }) : super(const SupportState()) {
    on<LoadSupportLinks>(_onLoadSupportLinks);
    on<CaptureSystemSnapshot>(_onCaptureSystemSnapshot);
    on<UpdateFeedbackType>(_onUpdateFeedbackType);
    on<UpdateFeedbackSubject>(_onUpdateFeedbackSubject);
    on<UpdateFeedbackMessage>(_onUpdateFeedbackMessage);
    on<AddAttachment>(_onAddAttachment);
    on<RemoveAttachment>(_onRemoveAttachment);
    on<SubmitFeedback>(_onSubmitFeedback);
    on<LoadTicketHistory>(_onLoadTicketHistory);
    on<OpenChat>(_onOpenChat);
    on<AddChatAttachment>(_onAddChatAttachment);
    on<RemoveChatAttachment>(_onRemoveChatAttachment);
    on<SendMessage>(_onSendMessage);
    on<UpdateChatMessages>(_onUpdateChatMessages);
    on<CloseChat>(_onCloseChat);
  }

  @override
  Future<void> close() {
    _messagesSubscription?.cancel();
    return super.close();
  }

  Future<void> _onLoadSupportLinks(LoadSupportLinks event, Emitter<SupportState> emit) async {
    emit(state.copyWith(isLoadingLinks: true));
    final result = await getSupportLinks();
    result.fold(
      (failure) => emit(state.copyWith(isLoadingLinks: false, error: failure.message)),
      (links) => emit(state.copyWith(isLoadingLinks: false, supportLinks: links)),
    );
  }

  Future<void> _onCaptureSystemSnapshot(CaptureSystemSnapshot event, Emitter<SupportState> emit) async {
    final result = await getSystemSnapshot();
    result.fold(
      (failure) => emit(state.copyWith(error: failure.message)),
      (snapshot) => emit(state.copyWith(systemSnapshot: snapshot)),
    );
  }

  void _onUpdateFeedbackType(UpdateFeedbackType event, Emitter<SupportState> emit) {
    emit(state.copyWith(feedbackType: event.type));
  }

  void _onUpdateFeedbackSubject(UpdateFeedbackSubject event, Emitter<SupportState> emit) {
    emit(state.copyWith(subject: event.subject));
  }

  void _onUpdateFeedbackMessage(UpdateFeedbackMessage event, Emitter<SupportState> emit) {
    emit(state.copyWith(message: event.message));
  }

  void _onAddAttachment(AddAttachment event, Emitter<SupportState> emit) {
    final attachments = List<File>.from(state.attachments)..add(event.file);
    emit(state.copyWith(attachments: attachments));
  }

  void _onRemoveAttachment(RemoveAttachment event, Emitter<SupportState> emit) {
    final attachments = List<File>.from(state.attachments)..removeAt(event.index);
    emit(state.copyWith(attachments: attachments));
  }

  Future<void> _onSubmitFeedback(SubmitFeedback event, Emitter<SupportState> emit) async {
    if (state.systemSnapshot == null) {
      add(const CaptureSystemSnapshot());
      return;
    }

    emit(state.copyWith(isSubmitting: true, error: null));

    final ticket = FeedbackTicket(
      userId: '', // Will be set by repository from Auth
      type: state.feedbackType,
      subject: state.subject,
      message: state.message,
      systemSnapshot: state.systemSnapshot!,
      attachmentUrls: const [],
      timestamp: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final result = await submitFeedback(
      ticket,
      state.attachments,
    );

    result.fold(
      (failure) => emit(state.copyWith(isSubmitting: false, error: failure.message)),
      (_) {
        emit(state.copyWith(
          isSubmitting: false,
          isSubmitted: true,
          subject: '',
          message: '',
          attachments: [],
        ));
        add(const LoadTicketHistory());
      },
    );
  }

  Future<void> _onLoadTicketHistory(LoadTicketHistory event, Emitter<SupportState> emit) async {
    emit(state.copyWith(isLoadingHistory: true));
    final result = await getTicketHistory();
    result.fold(
      (failure) => emit(state.copyWith(isLoadingHistory: false, error: failure.message)),
      (tickets) => emit(state.copyWith(isLoadingHistory: false, tickets: tickets)),
    );
  }

  Future<void> _onOpenChat(OpenChat event, Emitter<SupportState> emit) async {
    _messagesSubscription?.cancel();
    emit(state.copyWith(activeTicketId: event.ticketId, isLoadingMessages: true, messages: []));

    _messagesSubscription = getTicketMessages(event.ticketId).listen((result) {
      result.fold(
        (failure) => add(UpdateChatMessages(const [])), // or handle error better
        (messages) => add(UpdateChatMessages(messages)),
      );
    });
  }

  void _onUpdateChatMessages(UpdateChatMessages event, Emitter<SupportState> emit) {
    emit(state.copyWith(isLoadingMessages: false, messages: event.messages));
  }

  void _onAddChatAttachment(AddChatAttachment event, Emitter<SupportState> emit) {
    final attachments = List<File>.from(state.chatAttachments)..add(event.file);
    emit(state.copyWith(chatAttachments: attachments));
  }

  void _onRemoveChatAttachment(RemoveChatAttachment event, Emitter<SupportState> emit) {
    final attachments = List<File>.from(state.chatAttachments)..removeAt(event.index);
    emit(state.copyWith(chatAttachments: attachments));
  }

  Future<void> _onSendMessage(SendMessage event, Emitter<SupportState> emit) async {
    if (state.activeTicketId == null) return;

    emit(state.copyWith(isSendingMessage: true));

    final message = SupportMessage(
      id: '', // Will be generated by Firestore
      senderId: '', // Will be handled by repository
      senderType: MessageSenderType.user,
      text: event.text,
      timestamp: DateTime.now(),
      attachmentUrls: const [],
    );

    final result = await sendSupportMessage(state.activeTicketId!, message, attachments: state.chatAttachments);
    result.fold(
      (failure) => emit(state.copyWith(isSendingMessage: false, error: failure.message)),
      (_) => emit(state.copyWith(isSendingMessage: false, chatAttachments: [], error: null)),
    );
  }

  void _onCloseChat(CloseChat event, Emitter<SupportState> emit) {
    _messagesSubscription?.cancel();
    emit(state.copyWith(activeTicketId: null, messages: []));
  }
}

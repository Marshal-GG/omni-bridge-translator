import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:omni_bridge/core/constants/firebase_paths.dart';
import 'package:omni_bridge/core/utils/app_logger.dart';
import '../../domain/entities/feedback_ticket.dart';
import '../../domain/entities/support_message.dart';

abstract class ISupportRemoteDataSource {
  Future<void> submitFeedbackTicket(FeedbackTicket ticket);
  Future<List<String>> uploadAttachments(List<File> attachments, String userId);
  Future<List<FeedbackTicket>> getTickets(String userId);
  Stream<List<SupportMessage>> getTicketMessages(String ticketId);
  Future<void> sendSupportMessage(String ticketId, SupportMessage message, {List<File> attachments = const []});
}

class SupportRemoteDataSourceImpl implements ISupportRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;

  SupportRemoteDataSourceImpl({
    required this.firestore,
    required this.storage,
  });

  static const String _tag = 'SupportRemoteDataSource';

  @override
  Future<void> submitFeedbackTicket(FeedbackTicket ticket) async {
    try {
      await firestore.collection(FirebasePaths.feedbackTickets).doc(ticket.id).set(ticket.toJson());
      AppLogger.i('Feedback ticket ${ticket.id} submitted.', tag: _tag);
    } catch (e) {
      AppLogger.e('Failed to submit feedback ticket', error: e, tag: _tag);
      rethrow;
    }
  }

  @override
  Future<List<String>> uploadAttachments(List<File> attachments, String userId) async {
    final List<String> urls = [];
    AppLogger.i('Uploading ${attachments.length} attachments for user $userId', tag: _tag);
    for (final file in attachments) {
      try {
        final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split(Platform.pathSeparator).last}';
        final Reference ref = storage.ref().child('${FirebasePaths.feedbackAttachments}/$userId/$fileName');
        final UploadTask uploadTask = ref.putFile(file);
        final TaskSnapshot snapshot = await uploadTask;
        final String url = await snapshot.ref.getDownloadURL();
        urls.add(url);
      } catch (e) {
        AppLogger.e('Failed to upload attachment', error: e, tag: _tag);
      }
    }
    return urls;
  }

  @override
  Future<List<FeedbackTicket>> getTickets(String userId) async {
    final snapshot = await firestore
        .collection(FirebasePaths.feedbackTickets)
        .where('user_id', isEqualTo: userId)
        .orderBy('updated_at', descending: true)
        .get();

    return snapshot.docs.map((doc) => FeedbackTicket.fromJson(doc.data(), doc.id)).toList();
  }

  @override
  Stream<List<SupportMessage>> getTicketMessages(String ticketId) {
    return firestore
        .collection(FirebasePaths.feedbackTickets)
        .doc(ticketId)
        .collection(FirebasePaths.feedbackMessages)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => SupportMessage.fromJson(doc.data(), doc.id)).toList();
    });
  }

  @override
  Future<void> sendSupportMessage(String ticketId, SupportMessage message, {List<File> attachments = const []}) async {
    List<String> attachmentUrls = [];
    if (attachments.isNotEmpty) {
      attachmentUrls = await uploadAttachments(attachments, message.senderId);
    }

    final messageWithUrls = SupportMessage(
      id: message.id,
      senderId: message.senderId,
      senderType: message.senderType,
      text: message.text,
      attachmentUrls: [...message.attachmentUrls, ...attachmentUrls],
      timestamp: message.timestamp,
    );

    try {
      await firestore
          .collection(FirebasePaths.feedbackTickets)
          .doc(ticketId)
          .collection(FirebasePaths.feedbackMessages)
          .add(messageWithUrls.toJson());

      // Update last message and updatedAt in the ticket
      await firestore.collection(FirebasePaths.feedbackTickets).doc(ticketId).update({
        'last_message': messageWithUrls.text,
        'updated_at': messageWithUrls.timestamp.toIso8601String(),
      });
      AppLogger.i('Support message sent for ticket $ticketId', tag: _tag);
    } catch (e) {
      AppLogger.e('Failed to send support message', error: e, tag: _tag);
      rethrow;
    }
  }
}

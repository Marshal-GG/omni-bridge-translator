import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
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

  @override
  Future<void> submitFeedbackTicket(FeedbackTicket ticket) async {
    await firestore.collection('feedback_tickets').doc(ticket.id).set(ticket.toJson());
  }

  @override
  Future<List<String>> uploadAttachments(List<File> attachments, String userId) async {
    final List<String> urls = [];
    for (final file in attachments) {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split(Platform.pathSeparator).last}';
      final Reference ref = storage.ref().child('feedback_attachments/$userId/$fileName');
      final UploadTask uploadTask = ref.putFile(file);
      final TaskSnapshot snapshot = await uploadTask;
      final String url = await snapshot.ref.getDownloadURL();
      urls.add(url);
    }
    return urls;
  }

  @override
  Future<List<FeedbackTicket>> getTickets(String userId) async {
    final snapshot = await firestore
        .collection('feedback_tickets')
        .where('user_id', isEqualTo: userId)
        .orderBy('updated_at', descending: true)
        .get();

    return snapshot.docs.map((doc) => FeedbackTicket.fromJson(doc.data(), doc.id)).toList();
  }

  @override
  Stream<List<SupportMessage>> getTicketMessages(String ticketId) {
    return firestore
        .collection('feedback_tickets')
        .doc(ticketId)
        .collection('messages')
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

    await firestore
        .collection('feedback_tickets')
        .doc(ticketId)
        .collection('messages')
        .add(messageWithUrls.toJson());

    // Update last message and updatedAt in the ticket
    await firestore.collection('feedback_tickets').doc(ticketId).update({
      'last_message': messageWithUrls.text,
      'updated_at': messageWithUrls.timestamp.toIso8601String(),
    });
  }
}

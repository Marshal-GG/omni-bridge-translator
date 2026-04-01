import 'package:equatable/equatable.dart';

enum MessageSenderType { user, support }

class SupportMessage extends Equatable {
  final String id;
  final String senderId;
  final MessageSenderType senderType;
  final String text;
  final List<String> attachmentUrls;
  final DateTime timestamp;

  const SupportMessage({
    required this.id,
    required this.senderId,
    required this.senderType,
    required this.text,
    required this.attachmentUrls,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'sender_id': senderId,
      'sender_type': senderType.name,
      'text': text,
      'attachment_urls': attachmentUrls,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory SupportMessage.fromJson(Map<String, dynamic> json, String id) {
    return SupportMessage(
      id: id,
      senderId: json['sender_id'] as String? ?? 'unknown',
      senderType: MessageSenderType.values.firstWhere(
        (e) => e.name == json['sender_type'],
        orElse: () => MessageSenderType.user,
      ),
      text: json['text'] as String? ?? '',
      attachmentUrls: List<String>.from(json['attachment_urls'] as List? ?? []),
      timestamp: json['timestamp'] is String
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    senderId,
    senderType,
    text,
    attachmentUrls,
    timestamp,
  ];
}

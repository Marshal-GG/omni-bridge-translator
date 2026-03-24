import 'package:equatable/equatable.dart';
import 'system_snapshot.dart';

enum FeedbackType { bug, feature, improvement, support, other }

enum TicketStatus { open, inProgress, resolved, closed }

class FeedbackTicket extends Equatable {
  final String? id;
  final String userId;
  final FeedbackType type;
  final TicketStatus status;
  final String subject;
  final String message;
  final String lastMessage;
  final SystemSnapshot systemSnapshot;
  final List<String> attachmentUrls;
  final DateTime timestamp;
  final DateTime updatedAt;

  const FeedbackTicket({
    this.id,
    required this.userId,
    required this.type,
    this.status = TicketStatus.open,
    required this.subject,
    required this.message,
    this.lastMessage = '',
    required this.systemSnapshot,
    required this.attachmentUrls,
    required this.timestamp,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'type': type.name,
      'status': status.name,
      'subject': subject,
      'message': message,
      'last_message': lastMessage,
      'system_snapshot': systemSnapshot.toJson(),
      'attachment_urls': attachmentUrls,
      'timestamp': timestamp.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory FeedbackTicket.fromJson(Map<String, dynamic> json, String id) {
    return FeedbackTicket(
      id: id,
      userId: json['user_id'] as String? ?? 'anonymous',
      type: FeedbackType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => FeedbackType.other,
      ),
      status: TicketStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TicketStatus.open,
      ),
      subject: json['subject'] as String? ?? 'No Subject',
      message: json['message'] as String? ?? '',
      lastMessage: json['last_message'] as String? ?? '',
      systemSnapshot: SystemSnapshot.fromJson(json['system_snapshot'] as Map<String, dynamic>? ?? {}),
      attachmentUrls: List<String>.from(json['attachment_urls'] as List? ?? []),
      timestamp: json['timestamp'] is String
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(), // Fallback for FieldValue.serverTimestamp() in some cases
      updatedAt: json['updated_at'] is String
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        type,
        status,
        subject,
        message,
        lastMessage,
        systemSnapshot,
        attachmentUrls,
        timestamp,
        updatedAt,
      ];
}

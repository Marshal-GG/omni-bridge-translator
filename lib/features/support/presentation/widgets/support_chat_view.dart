import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../blocs/support_bloc.dart';
import '../../domain/entities/feedback_ticket.dart';
import '../../domain/entities/support_message.dart';
import 'chat_input_widget.dart';

class SupportChatView extends StatelessWidget {
  const SupportChatView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SupportBloc, SupportState>(
      builder: (context, state) {
        if (state.activeTicketId == null) {
          return const Center(child: Text('Select a ticket to view conversation'));
        }

        final ticket = state.tickets.firstWhere(
          (t) => t.id == state.activeTicketId,
          orElse: () => state.tickets.first,
        );

        return Column(
          children: [
            _buildChatHeader(context, ticket),
            Expanded(
              child: _buildMessagesList(state, ticket),
            ),
            const ChatInputWidget(),
          ],
        );
      },
    );
  }

  Widget _buildChatHeader(BuildContext context, FeedbackTicket ticket) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        border: const Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticket.subject,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Ticket #${ticket.id?.substring(0, 8).toUpperCase() ?? ""}',
                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.3)),
                ),
              ],
            ),
          ),
          _buildStatusTag(ticket.status),
        ],
      ),
    );
  }

  Widget _buildStatusTag(TicketStatus status) {
    Color color;
    switch (status) {
      case TicketStatus.open: color = Colors.blueAccent; break;
      case TicketStatus.inProgress: color = Colors.orangeAccent; break;
      case TicketStatus.resolved: color = Colors.greenAccent; break;
      case TicketStatus.closed: color = Colors.grey; break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMessagesList(SupportState state, FeedbackTicket ticket) {
    if (state.isLoadingMessages) {
      return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      reverse: true,
      itemCount: state.messages.length + 1,
      itemBuilder: (context, index) {
        if (index == state.messages.length) {
          return _MessageBubble(
            text: ticket.message,
            senderType: MessageSenderType.user,
            timestamp: ticket.timestamp,
            attachmentUrls: ticket.attachmentUrls,
            isInitial: true,
          );
        }
        
        final message = state.messages[state.messages.length - 1 - index];
        return _MessageBubble(
          text: message.text,
          senderType: message.senderType,
          timestamp: message.timestamp,
          attachmentUrls: message.attachmentUrls,
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final MessageSenderType senderType;
  final DateTime timestamp;
  final List<String> attachmentUrls;
  final bool isInitial;

  const _MessageBubble({
    required this.text,
    required this.senderType,
    required this.timestamp,
    this.attachmentUrls = const [],
    this.isInitial = false,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = senderType == MessageSenderType.user;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.5),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUser 
                  ? Colors.cyanAccent.withValues(alpha: 0.1) 
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
              border: Border.all(
                color: isUser 
                    ? Colors.cyanAccent.withValues(alpha: 0.2) 
                    : Colors.white10,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isInitial)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Initial Description',
                      style: TextStyle(
                        fontSize: 10, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.cyanAccent.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                if (text.isNotEmpty)
                  Text(
                    text,
                    style: const TextStyle(fontSize: 14, color: Color(0xFFE8E8E8), height: 1.4),
                  ),
                if (attachmentUrls.isNotEmpty) ...[
                  if (text.isNotEmpty) const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: attachmentUrls.map((url) => _buildAttachmentItem(url)).toList(),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
            child: Text(
              DateFormat('h:mm a').format(timestamp),
              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.2)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentItem(String url) {
    final isImage = url.toLowerCase().contains('.png') || 
                    url.toLowerCase().contains('.jpg') || 
                    url.toLowerCase().contains('.jpeg');

    return InkWell(
      onTap: () => launchUrl(Uri.parse(url)),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isImage ? Icons.image : Icons.insert_drive_file,
              size: 16,
              color: Colors.cyanAccent,
            ),
            const SizedBox(width: 8),
            const Text(
              'View File',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

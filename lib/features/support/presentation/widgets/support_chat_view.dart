import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../blocs/support_bloc.dart';
import '../../domain/entities/feedback_ticket.dart';
import '../../domain/entities/support_message.dart';
import 'package:omni_bridge/core/widgets/omni_badge.dart';
import 'chat_input_widget.dart';

class SupportChatView extends StatelessWidget {
  const SupportChatView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SupportBloc, SupportState>(
      builder: (context, state) {
        if (state.activeTicketId == null) {
          return Center(
            child: Text(
              'Select a ticket to view conversation',
              style: AppTextStyles.body.copyWith(color: AppColors.white54),
            ),
          );
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
        color: Color(0x05FFFFFF), // Very subtle white (0.02)
        border: Border(bottom: BorderSide(color: AppColors.white10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticket.subject,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Ticket #${ticket.id?.substring(0, 8).toUpperCase() ?? ""}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.whiteOpacity(0.3)),
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
      case TicketStatus.open: color = AppColors.statusOpen; break;
      case TicketStatus.inProgress: color = AppColors.statusInProgress; break;
      case TicketStatus.resolved: color = AppColors.statusResolved; break;
      case TicketStatus.closed: color = AppColors.statusClosed; break;
    }

    return OmniBadge(
      text: status.name.toUpperCase(),
      color: color,
    );
  }

  Widget _buildMessagesList(SupportState state, FeedbackTicket ticket) {
    if (state.isLoadingMessages) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentCyan));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
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
                    ? AppColors.accentCyan.withValues(alpha: 0.2) 
                    : AppColors.white10,
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
                      style: AppTextStyles.labelTiny.copyWith(
                        fontWeight: FontWeight.bold, 
                        color: AppColors.accentCyan.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                if (text.isNotEmpty)
                  Text(
                    text,
                    style: AppTextStyles.chatMessage,
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
              style: AppTextStyles.labelTiny.copyWith(color: AppColors.whiteOpacity(0.2)),
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
      borderRadius: AppShapes.md,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.whiteOpacity(0.05),
          borderRadius: AppShapes.md,
          border: Border.all(color: AppColors.white10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isImage ? Icons.image : Icons.insert_drive_file,
              size: 16,
              color: AppColors.accentCyan,
            ),
            const SizedBox(width: 8),
            Text(
              'View File',
              style: AppTextStyles.caption.copyWith(color: AppColors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

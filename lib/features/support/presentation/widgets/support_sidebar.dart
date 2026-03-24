import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/support_bloc.dart';
import '../../domain/entities/feedback_ticket.dart';

class SupportSidebar extends StatelessWidget {
  const SupportSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        border: Border(right: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          _buildHeader(context),
          _buildSearchField(),
          const Divider(height: 1, color: Colors.white10),
          Expanded(
            child: BlocBuilder<SupportBloc, SupportState>(
              builder: (context, state) {
                if (state.isLoadingHistory) {
                  return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
                }

                if (state.tickets.isEmpty) {
                  return _buildEmptyState(context);
                }

                return ListView.builder(
                  itemCount: state.tickets.length,
                  itemBuilder: (context, index) {
                    final ticket = state.tickets[index];
                    final isActive = state.activeTicketId == ticket.id;
                    return _TicketListTile(
                      ticket: ticket,
                      isActive: isActive,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 12, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Support',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined, color: Colors.cyanAccent, size: 22),
            onPressed: () {
              context.read<SupportBloc>().add(const CloseChat()); // This will show the "New Ticket" form
            },
            tooltip: 'New Request',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: TextField(
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search tickets...',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
          prefixIcon: Icon(Icons.search, size: 18, color: Colors.white.withValues(alpha: 0.3)),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.03),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            Text(
              'No tickets found',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.read<SupportBloc>().add(const LoadTicketHistory()),
              child: const Text('Refresh', style: TextStyle(color: Colors.cyanAccent)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketListTile extends StatelessWidget {
  final FeedbackTicket ticket;
  final bool isActive;

  const _TicketListTile({
    required this.ticket,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        context.read<SupportBloc>().add(OpenChat(ticket.id!));
      },
      child: Container(
        color: isActive ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _buildAvatar(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          ticket.subject,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isActive ? Colors.cyanAccent : Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatDate(ticket.updatedAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ticket.lastMessage.isNotEmpty ? ticket.lastMessage : ticket.message,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (ticket.status == TicketStatus.open || ticket.status == TicketStatus.inProgress)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _getStatusColor(ticket.status),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _getStatusColor(ticket.status).withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: _getStatusColor(ticket.status).withValues(alpha: 0.2)),
      ),
      child: Icon(
        _getStatusIcon(ticket.status),
        size: 20,
        color: _getStatusColor(ticket.status),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return DateFormat('h:mm a').format(date);
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return DateFormat('EEEE').format(date);
    return DateFormat('MMM d').format(date);
  }

  Color _getStatusColor(TicketStatus status) {
    switch (status) {
      case TicketStatus.open: return Colors.blueAccent;
      case TicketStatus.inProgress: return Colors.orangeAccent;
      case TicketStatus.resolved: return Colors.greenAccent;
      case TicketStatus.closed: return Colors.grey;
    }
  }

  IconData _getStatusIcon(TicketStatus status) {
    switch (status) {
      case TicketStatus.open: return Icons.mark_chat_unread_outlined;
      case TicketStatus.inProgress: return Icons.forum_outlined;
      case TicketStatus.resolved: return Icons.check_circle_outline;
      case TicketStatus.closed: return Icons.lock_clock_outlined;
    }
  }
}

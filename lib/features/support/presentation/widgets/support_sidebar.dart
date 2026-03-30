import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../blocs/support_bloc.dart';
import '../../domain/entities/feedback_ticket.dart';
import 'package:omni_bridge/core/widgets/omni_badge.dart';
import 'package:omni_bridge/core/widgets/omni_search_bar.dart';
import 'support_new_ticket_button.dart';

class SupportSidebar extends StatelessWidget {
  const SupportSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSpacing.ticketListWidth,
      decoration: const BoxDecoration(
        color: Colors.transparent,
        border: Border(
          right: BorderSide(color: Colors.white10),
        ),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              _buildSearchHeader(context),
              Expanded(
                child: BlocBuilder<SupportBloc, SupportState>(
                  builder: (context, state) {
                    if (state.isLoadingHistory) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.accentCyan));
                    }

                    if (state.error != null && state.tickets.isEmpty) {
                      return _buildErrorState(context, state.error!);
                    }

                    if (state.tickets.isEmpty) {
                      return _buildEmptyState(context);
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
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
          // Floating New Ticket Button - Bottom Right
          Positioned(
            bottom: 24,
            right: 16,
            child: SupportNewTicketButton(
              onTap: () {
                // Trigger new ticket flow
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.sm),
      child: OmniSearchBar(
        hintText: 'Search tickets...',
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
            Icon(Icons.history_rounded, size: 48, color: AppColors.white24),
            const SizedBox(height: 16),
            const Text(
              'No tickets found',
              style: TextStyle(color: AppColors.white54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => context.read<SupportBloc>().add(const LoadTicketHistory()),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.accentRed),
            const SizedBox(height: 16),
            Text(
              'Failed to load tickets',
              style: TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(color: AppColors.white54, fontSize: 11),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.read<SupportBloc>().add(const LoadTicketHistory()),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () {
          context.read<SupportBloc>().add(OpenChat(ticket.id!));
        },
        borderRadius: AppShapes.lg,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isActive 
                ? Colors.tealAccent.withValues(alpha: 0.05)
                : Colors.transparent,
            borderRadius: AppShapes.lg,
            border: Border.all(
              color: isActive 
                  ? Colors.tealAccent.withValues(alpha: 0.2)
                  : Colors.transparent,
            ),
          ),
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
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isActive ? AppColors.accentCyan : AppColors.offWhite,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _formatTime(ticket.updatedAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.white54.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                ticket.lastMessage.isNotEmpty ? ticket.lastMessage : ticket.message,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.white54,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StatusTag(status: ticket.status),
                  const _AvatarStack(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d').format(date);
  }
}

class _StatusTag extends StatelessWidget {
  final TicketStatus status;
  const _StatusTag({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case TicketStatus.open:
        color = AppColors.accentCyan; label = 'NEW'; break;
      case TicketStatus.inProgress:
        color = AppColors.translationTeal; label = 'ACTIVE'; break;
      case TicketStatus.resolved:
        color = Colors.greenAccent; label = 'RESOLVED'; break;
      case TicketStatus.closed:
        color = AppColors.white54; label = 'CLOSED'; break;
    }

    return OmniBadge(text: label, color: color);
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 18,
      child: Stack(
        children: [
          Positioned(
            right: 0,
            child: CircleAvatar(
              radius: 9,
              backgroundColor: AppColors.surfaceLight,
              child: CircleAvatar(
                radius: 8,
                backgroundColor: AppColors.accentCyan.withValues(alpha: 0.15),
                child: const Icon(Icons.person, size: 10, color: AppColors.accentCyan),
              ),
            ),
          ),
          Positioned(
            right: 12,
            child: CircleAvatar(
              radius: 9,
              backgroundColor: AppColors.surfaceLight,
              child: const CircleAvatar(
                radius: 8,
                backgroundColor: Colors.white12,
                child: Icon(Icons.support_agent, size: 10, color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

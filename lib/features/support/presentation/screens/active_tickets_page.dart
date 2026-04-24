// Copyright (c) 2026 Omni Bridge. All rights reserved.
//
// Licensed under the PERSONAL STUDY & LEARNING LICENSE v1.0.
// Commercial use and public redistribution of modified versions are strictly prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../blocs/support_bloc.dart';
import '../../domain/entities/feedback_ticket.dart';

/// Displays a dashboard of the user's tickets filtered by [tabIndex].
///
/// Tab indices match [AppNavigationRail._supportSubTabs]:
///   0 – All, 1 – Active (open + inProgress), 2 – Pending (inProgress),
///   3 – Resolved, 4 – Archive (closed).
///
/// Colour tokens, spacing, radii and motion durations all come from
/// [AppColors], [AppSpacing], [AppShapes], and [AppTextStyles] per DESIGN.md.
class ActiveTicketsPage extends StatelessWidget {
  /// Which nav-rail sub-tab is currently selected.
  final int tabIndex;

  const ActiveTicketsPage({super.key, this.tabIndex = 0});

  /// Returns the tickets that match [tabIndex] from the full [tickets] list.
  List<FeedbackTicket> _filter(List<FeedbackTicket> tickets) {
    switch (tabIndex) {
      case 1: // Active
        return tickets
            .where(
              (t) =>
                  t.status == TicketStatus.open ||
                  t.status == TicketStatus.inProgress,
            )
            .toList();
      case 2: // Pending
        return tickets
            .where((t) => t.status == TicketStatus.inProgress)
            .toList();
      case 3: // Resolved
        return tickets
            .where((t) => t.status == TicketStatus.resolved)
            .toList();
      case 4: // Archive
        return tickets
            .where((t) => t.status == TicketStatus.closed)
            .toList();
      default: // All Tickets
        return tickets;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SupportBloc, SupportState>(
      builder: (context, state) {
        if (state.isLoadingHistory) {
          return _buildLoadingState();
        }

        final filtered = _filter(state.tickets);

        return _ActiveTicketsDashboard(
          activeTickets: filtered,
          allTickets: state.tickets,
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: const AlwaysStoppedAnimation(AppColors.accentTeal),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading tickets…',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dashboard body
// ---------------------------------------------------------------------------

class _ActiveTicketsDashboard extends StatelessWidget {
  final List<FeedbackTicket> activeTickets;
  final List<FeedbackTicket> allTickets;

  const _ActiveTicketsDashboard({
    required this.activeTickets,
    required this.allTickets,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.sm),

          // ── Summary strip ───────────────────────────────────────────────
          _SummaryStrip(
            total: allTickets.length,
            activeCount: activeTickets.length,
            resolvedCount: allTickets
                .where((t) => t.status == TicketStatus.resolved)
                .length,
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Section header ───────────────────────────────────────────────
          _SectionHeader(
            label: 'ACTIVE TICKETS',
            color: AppColors.accentTeal,
            count: activeTickets.length,
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Ticket list or empty state ───────────────────────────────────
          if (activeTickets.isEmpty)
            _EmptyActiveState(
              onNewTicket: () =>
                  context.read<SupportBloc>().add(const LoadTicketHistory()),
            )
          else
            ...activeTickets.map(
              (ticket) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _ActiveTicketCard(ticket: ticket),
              ),
            ),

          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary strip — mirrors §12.4 "stats strip" from DESIGN.md
// ---------------------------------------------------------------------------

class _SummaryStrip extends StatelessWidget {
  final int total;
  final int activeCount;
  final int resolvedCount;

  const _SummaryStrip({
    required this.total,
    required this.activeCount,
    required this.resolvedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        // Subtle teal tint — mirrors the stats strip gradient
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accentTeal.withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ),
        borderRadius: AppShapes.lg,
        border: Border.all(
          color: AppColors.accentTeal.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          // Left accent bar (§12.4)
          Container(
            width: 3,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.accentTeal,
                  AppColors.accentTeal.withValues(alpha: 0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Row(
              children: [
                _StatCell(
                  label: 'TOTAL',
                  value: '$total',
                  color: AppColors.accentTeal,
                ),
                const SizedBox(width: AppSpacing.md),
                _StatCell(
                  label: 'ACTIVE',
                  value: '$activeCount',
                  color: AppColors.statusOpen,
                ),
                const SizedBox(width: AppSpacing.md),
                _StatCell(
                  label: 'RESOLVED',
                  value: '$resolvedCount',
                  color: AppColors.statusResolved,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mini stat tile — §7.19 StatCell pattern
class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCell({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTextStyles.labelTiny.copyWith(
                  letterSpacing: 0.6,
                  color: AppColors.textDisabled,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header — §7.21 SectionHeader
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  final int count;

  const _SectionHeader({
    required this.label,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Dot indicator
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [BoxShadow(color: color, blurRadius: 6)],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.08 * 11,
            color: color.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(width: 8),
        // Count chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.cardBorder,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Active ticket card
// ---------------------------------------------------------------------------

class _ActiveTicketCard extends StatefulWidget {
  final FeedbackTicket ticket;

  const _ActiveTicketCard({required this.ticket});

  @override
  State<_ActiveTicketCard> createState() => _ActiveTicketCardState();
}

class _ActiveTicketCardState extends State<_ActiveTicketCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(widget.ticket.status);
    final statusLabel = _statusLabel(widget.ticket.status);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (widget.ticket.id != null) {
            context.read<SupportBloc>().add(OpenChat(widget.ticket.id!));
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200), // AppMotion.quick
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.accentTeal.withValues(alpha: 0.04)
                : AppColors.cardBackground,
            borderRadius: AppShapes.lg,
            border: Border.all(
              color: _hovered
                  ? AppColors.accentTeal.withValues(alpha: 0.25)
                  : AppColors.cardBorder,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status indicator bar (left edge)
              Container(
                width: 3,
                height: 56,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    if (_hovered)
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Ticket details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subject + timestamp row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.ticket.subject,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _hovered
                                  ? AppColors.accentTeal
                                  : AppColors.textPrimary,
                              letterSpacing: -0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          _formatRelative(widget.ticket.updatedAt),
                          style: AppTextStyles.labelTiny.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Last message preview
                    Text(
                      widget.ticket.lastMessage.isNotEmpty
                          ? widget.ticket.lastMessage
                          : widget.ticket.message,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Footer: type chip + status badge
                    Row(
                      children: [
                        _TypeChip(type: widget.ticket.type),
                        const SizedBox(width: AppSpacing.xs),
                        _StatusBadge(
                          label: statusLabel,
                          color: statusColor,
                        ),
                        const Spacer(),
                        // Ticket ID
                        Text(
                          '#${widget.ticket.id?.substring(0, 6).toUpperCase() ?? '------'}',
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: AppColors.textFaint,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Chevron
              const SizedBox(width: AppSpacing.sm),
              AnimatedOpacity(
                opacity: _hovered ? 1.0 : 0.3,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.accentTeal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _statusColor(TicketStatus status) {
    switch (status) {
      case TicketStatus.open:
        return AppColors.statusOpen;
      case TicketStatus.inProgress:
        return AppColors.statusInProgress;
      case TicketStatus.resolved:
        return AppColors.statusResolved;
      case TicketStatus.closed:
        return AppColors.statusClosed;
    }
  }

  static String _statusLabel(TicketStatus status) {
    switch (status) {
      case TicketStatus.open:
        return 'OPEN';
      case TicketStatus.inProgress:
        return 'IN PROGRESS';
      case TicketStatus.resolved:
        return 'RESOLVED';
      case TicketStatus.closed:
        return 'CLOSED';
    }
  }

  static String _formatRelative(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(date);
  }
}

// ---------------------------------------------------------------------------
// Type chip — §7.3 Chip / pill pattern
// ---------------------------------------------------------------------------

class _TypeChip extends StatelessWidget {
  final FeedbackType type;

  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      FeedbackType.bug => ('BUG', AppColors.accentRed),
      FeedbackType.feature => ('FEATURE', AppColors.accentCyan),
      FeedbackType.improvement => ('IMPROVE', AppColors.translationTeal),
      FeedbackType.support => ('SUPPORT', AppColors.semanticAsr.withValues(alpha: 1)),
      FeedbackType.other => ('OTHER', AppColors.textMuted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.08 * 9,
          color: color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status badge — §7.3 Chip
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [BoxShadow(color: color, blurRadius: 4)],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.08 * 9,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state — §7.25
// ---------------------------------------------------------------------------

class _EmptyActiveState extends StatelessWidget {
  final VoidCallback onNewTicket;

  const _EmptyActiveState({required this.onNewTicket});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 36,
              color: AppColors.statusResolved.withValues(alpha: 0.6),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No active tickets',
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'All caught up. Open a new support request below.',
              style: AppTextStyles.caption.copyWith(color: AppColors.textFaint),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onNewTicket,
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentTeal,
                side: BorderSide(
                  color: AppColors.accentTeal.withValues(alpha: 0.3),
                ),
                textStyle: AppTextStyles.label,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs + 4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: AppShapes.md,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

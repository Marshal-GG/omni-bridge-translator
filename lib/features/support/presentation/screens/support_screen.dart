import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omni_bridge/core/di/di.dart';
import '../../../../core/theme/app_theme.dart';
import '../blocs/support_bloc.dart';
import '../widgets/support_sidebar.dart';
import '../widgets/support_chat_view.dart';
import 'active_tickets_page.dart';
import '../widgets/support_header.dart';
import 'package:omni_bridge/features/shell/presentation/widgets/app_dashboard_shell.dart';
import 'package:omni_bridge/core/navigation/app_router.dart';
import 'package:omni_bridge/core/widgets/omni_badge.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final initialTabIndex = args is int ? args : 0;

    return BlocProvider(
      create: (context) => sl<SupportBloc>()
        ..add(const LoadSupportLinks())
        ..add(const CaptureSystemSnapshot())
        ..add(const LoadTicketHistory())
        ..add(SupportTabChanged(initialTabIndex)),
      child: BlocBuilder<SupportBloc, SupportState>(
        builder: (context, state) {
          return AppDashboardShell(
            currentRoute: AppRouter.support,
            supportTabIndex: state.activeTabIndex,
            onSupportTabChanged: (i) => context.read<SupportBloc>().add(SupportTabChanged(i)),
            header: buildSupportHeader(context),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const SupportSidebar(),
                      Expanded(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.transparent, // Let OmniWindowLayout background show through
                          ),
                          child: Stack(
                            children: [
                              // Content
                              Positioned.fill(
                                child: Column(
                                  children: [
                                    _buildChatSubHeader(context, state),
                                    Expanded(
                                      child: state.activeTicketId != null
                                          ? const SupportChatView()
                                          : ActiveTicketsPage(
                                              tabIndex: state.activeTabIndex,
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatSubHeader(BuildContext context, SupportState state) {
    if (state.activeTicketId == null) return const SizedBox.shrink();

    final ticket = state.tickets.firstWhere(
      (t) => t.id == state.activeTicketId,
      orElse: () => state.tickets.first,
    );

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.6),
        border: Border(
          bottom: BorderSide(color: AppColors.white24.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Ticket #${ticket.id?.substring(0, 4).toUpperCase() ?? ""}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentCyan,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  ticket.subject,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.offWhite,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          OmniBadge(
            text: ticket.status.name.toUpperCase(),
            color: AppColors.accentCyan,
          ),
        ],
      ),
    );
  }
}


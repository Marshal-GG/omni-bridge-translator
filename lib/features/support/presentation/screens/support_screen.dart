import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omni_bridge/core/platform/window_manager.dart';
import 'package:omni_bridge/core/di/injection.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../blocs/support_bloc.dart';
import '../widgets/support_sidebar.dart';
import '../widgets/support_navigation_rail.dart';
import '../widgets/support_chat_view.dart';
import '../widgets/feedback_form.dart';
import '../widgets/support_footer.dart';
import '../widgets/support_header.dart';
import 'package:omni_bridge/features/shell/presentation/widgets/app_dashboard_shell.dart';
import 'package:omni_bridge/core/navigation/app_router.dart';
import 'package:omni_bridge/core/widgets/omni_card.dart';
import 'package:omni_bridge/core/widgets/omni_version_chip.dart';
import 'package:omni_bridge/core/widgets/omni_badge.dart';
import '../../domain/entities/support_link.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  @override
  void initState() {
    super.initState();
    pathToResizingWindow();
  }

  void pathToResizingWindow() {
    setToSupportPosition();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => sl<SupportBloc>()
        ..add(const LoadSupportLinks())
        ..add(const CaptureSystemSnapshot())
        ..add(const LoadTicketHistory()),
      child: AppDashboardShell(
        currentRoute: AppRouter.support,
        child: Column(
          children: [
            buildSupportHeader(context),
            Expanded(
              child: Row(
                children: [
                  const SupportNavigationRail(),
                  const SupportSidebar(),
                  Expanded(
                    child: BlocBuilder<SupportBloc, SupportState>(
                      builder: (context, state) {
                        return Container(
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
                                          : _buildDefaultDashboard(context, state),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

  Widget _buildDefaultDashboard(BuildContext context, SupportState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: 40.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxDashboardWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 40),
              Text(
                'Help & Support',
                style: AppTextStyles.display.copyWith(color: AppColors.offWhite),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Select a ticket from the sidebar or create a new request below.',
                style: TextStyle(color: AppColors.white54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              _buildHelpLinksGrid(state),
              const SizedBox(height: 64),
              const Divider(color: AppColors.white10),
              const SizedBox(height: 64),
              const FeedbackForm(),
              const SizedBox(height: 64),
              buildSupportFooter(context),
              const SizedBox(height: 24),
              const OmniVersionChip(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpLinksGrid(SupportState state) {
    if (state.isLoadingLinks) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentCyan));
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 2.8,
      ),
      itemCount: state.supportLinks.length,
      itemBuilder: (context, index) {
        final link = state.supportLinks[index];
        return _SupportLinkCard(link: link);
      },
    );
  }
}



class _SupportLinkCard extends StatelessWidget {
  final SupportLink link;

  const _SupportLinkCard({required this.link});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(link.url)),
      borderRadius: AppShapes.lg,
      child: OmniCard(
        padding: const EdgeInsets.all(16),
        hasGlow: true,
        baseColor: Colors.tealAccent,
        child: Row(
          children: [
            Icon(_getIconForSlug(link.icon), color: AppColors.accentCyan, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    link.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.offWhite,
                    ),
                  ),
                  Text(
                    link.description,
                    style: TextStyle(
                      fontSize: 10,
                       color: AppColors.white54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForSlug(String slug) {
    switch (slug) {
      case 'guide': return Icons.menu_book;
      case 'faq': return Icons.quiz;
      case 'discord': return Icons.chat_bubble;
      case 'twitter': return Icons.alternate_email;
      default: return Icons.link;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/platform/window_manager.dart';
import '../../../subscription/presentation/widgets/version_chip.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/support_link.dart';
import '../blocs/support_bloc.dart';
import '../widgets/feedback_form.dart';
import '../widgets/support_branding.dart';
import '../widgets/support_header.dart';
import '../widgets/support_footer.dart';
import '../widgets/support_sidebar.dart';
import '../widgets/support_chat_view.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  String _version = '1.0.0';

  @override
  void initState() {
    super.initState();
    pathToResizingWindow();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
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
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: WindowBorder(
          color: Colors.white12,
          width: 1,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF161616), Color(0xFF0F0F0F)],
              ),
            ),
            child: Column(
              children: [
                buildSupportHeader(context),
                const Divider(height: 1, color: Colors.white10),
                Expanded(
                  child: BlocBuilder<SupportBloc, SupportState>(
                    builder: (context, state) {
                      return Row(
                        children: [
                          const SupportSidebar(),
                          Expanded(
                            child: state.activeTicketId != null
                                ? const SupportChatView()
                                : _buildDefaultDashboard(state),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultDashboard(SupportState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 40),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                children: [
                  buildSupportBranding(),
                  const SizedBox(height: 40),
                  const Text(
                    'Help & Support',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select a ticket from the sidebar or create a new request below.',
                    style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.5)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  _buildHelpLinksGrid(state),
                  const SizedBox(height: 64),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 64),
                  const FeedbackForm(),
                  const SizedBox(height: 64),
                  buildSupportFooter(context),
                  const SizedBox(height: 24),
                  buildVersionChip(label: 'v$_version'),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHelpLinksGrid(SupportState state) {
    if (state.isLoadingLinks) {
       return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Icon(_getIconForSlug(link.icon), color: Colors.cyanAccent, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    link.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    link.description,
                    style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4)),
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

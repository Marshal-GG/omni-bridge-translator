import 'package:flutter/material.dart';
import 'package:omni_bridge/core/constants/firebase_paths.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omni_bridge/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:omni_bridge/features/about/domain/entities/update_result.dart';
import 'package:omni_bridge/features/about/presentation/blocs/about_bloc.dart';
import 'package:omni_bridge/features/about/presentation/blocs/about_event.dart';
import 'package:omni_bridge/features/about/presentation/blocs/about_state.dart';
import 'package:omni_bridge/core/widgets/omni_branding.dart';
import 'package:omni_bridge/core/widgets/omni_copyright.dart';
import 'package:omni_bridge/core/widgets/omni_header.dart';
import 'package:omni_bridge/features/shell/presentation/widgets/app_dashboard_shell.dart';
import 'package:omni_bridge/core/widgets/omni_chip.dart';
import 'package:omni_bridge/core/navigation/app_router.dart';
import 'package:omni_bridge/features/startup/presentation/widgets/update_download_button.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final GlobalKey _contentKey = GlobalKey();

  Future<void> _handleUpdateCheck(BuildContext context) async {
    context.read<AboutBloc>().add(const AboutCheckUpdateEvent());
  }

  void _showSplashPreview(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: SizedBox(
          width: 300,
          height: 350,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0F),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/app/icons/icon.png',
                        width: 96,
                        height: 96,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Omni Bridge',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Starting up...',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 32, right: 32, bottom: 40),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const SizedBox(
                      height: 6,
                      child: LinearProgressIndicator(
                        backgroundColor: Color(0xFF1E1E2E),
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00BCD4)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDashboardShell(
      currentRoute: AppRouter.about,
      header: OmniHeader(
        title: 'About Omni Bridge',
        icon: Icons.info_outline_rounded,
        onBack: () => Navigator.of(context).pop(),
        onClose: () => Navigator.of(context).pop(),
      ),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 1000,
                        key: _contentKey,
                        child: BlocBuilder<AboutBloc, AboutState>(
                          builder: (context, state) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 28,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // ── Branding ───────────────────────────────────
                                  OmniBranding(
                                    subtitle: 'Live AI Translator',
                                    fallbackIcon: Icons.info_outline_rounded,
                                    bottomWidget: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // ── Check for Updates ──────────────────
                                        SizedBox(
                                          height: 26,
                                          child: OutlinedButton(
                                            onPressed:
                                                state.updateStatus ==
                                                    UpdateStatus.checking
                                                ? null
                                                : () => _handleUpdateCheck(
                                                    context,
                                                  ),
                                            style: OutlinedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 0,
                                                  ),
                                              side: BorderSide(
                                                color:
                                                    state.updateStatus ==
                                                        UpdateStatus.checking
                                                    ? Colors.white10
                                                    : Colors.tealAccent
                                                          .withValues(
                                                            alpha: 0.3,
                                                          ),
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              foregroundColor:
                                                  Colors.tealAccent,
                                              backgroundColor: Colors.tealAccent
                                                  .withValues(alpha: 0.02),
                                            ),
                                            child:
                                                state.updateStatus ==
                                                    UpdateStatus.checking
                                                ? const SizedBox(
                                                    width: 10,
                                                    height: 10,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 1.5,
                                                          color: Colors.white38,
                                                        ),
                                                  )
                                                : Text(
                                                    state.updateStatus ==
                                                            UpdateStatus.idle
                                                        ? 'Check for updates'
                                                        : 'Check again',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        // Status result shown below
                                        if (state.updateStatus !=
                                                UpdateStatus.idle &&
                                            state.updateStatus !=
                                                UpdateStatus.checking) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (state.updateStatus ==
                                                  UpdateStatus.upToDate)
                                                const Icon(
                                                  Icons
                                                      .check_circle_outline_rounded,
                                                  size: 11,
                                                  color: Colors.tealAccent,
                                                )
                                              else if (state.updateStatus ==
                                                  UpdateStatus.available)
                                                const Icon(
                                                  Icons.upgrade_rounded,
                                                  size: 11,
                                                  color: Colors.orangeAccent,
                                                )
                                              else if (state.updateStatus ==
                                                  UpdateStatus.error)
                                                const Icon(
                                                  Icons.error_outline_rounded,
                                                  size: 11,
                                                  color: Colors.redAccent,
                                                ),
                                              const SizedBox(width: 4),
                                              if (state.updateStatus ==
                                                  UpdateStatus.upToDate)
                                                const Text(
                                                  'Up to date',
                                                  style: TextStyle(
                                                    color: Colors.tealAccent,
                                                    fontSize: 10,
                                                  ),
                                                )
                                              else if (state.updateStatus ==
                                                  UpdateStatus.available)
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      'v${state.updateResult?.latestVersion} available — ',
                                                      style: const TextStyle(
                                                        color: Colors.orangeAccent,
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                    UpdateDownloadButton(
                                                      releaseUrl: state.updateResult?.releaseUrl ?? '',
                                                      downloadUrl: state.updateResult?.downloadUrl,
                                                    ),
                                                  ],
                                                )
                                              else if (state.updateStatus ==
                                                  UpdateStatus.error)
                                                Text(
                                                  state
                                                          .updateResult
                                                          ?.errorMessage ??
                                                      'Check failed.',
                                                  style: const TextStyle(
                                                    color: Colors.redAccent,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ], // Column children
                                    ), // Column (bottomWidget)
                                  ), // OmniBranding
                                  const SizedBox(height: 24),

                                  // ── Optimized Dual-Column Layout with Bottom Alignment ──
                                  IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Left Column: About, Built With, and License
                                        Expanded(
                                          child: Column(
                                            children: [
                                              _InfoCard(
                                                icon:
                                                    Icons.info_outline_rounded,
                                                title: 'About Omni Bridge',
                                                content:
                                                    'Omni Bridge is a real-time AI translator for Windows that provides ultra-low latency captions and translations from any audio source — YouTube, meetings, or your microphone. Powered by Google, NVIDIA, and OpenAI, it bridges language gaps and improves accessibility through a sleek, customizable overlay.',
                                              ),
                                              const SizedBox(height: 12),
                                              _InfoCard(
                                                icon: Icons.code_rounded,
                                                title: 'Built With',
                                                content: null,
                                                child: const Wrap(
                                                  spacing: 6,
                                                  runSpacing: 6,
                                                  children: [
                                                    OmniChip(label: 'Flutter'),
                                                    OmniChip(label: 'FastAPI'),
                                                    OmniChip(label: 'Firebase'),
                                                    OmniChip(
                                                      label: 'NVIDIA Riva',
                                                    ),
                                                    OmniChip(label: 'Whisper'),
                                                    OmniChip(
                                                      label: 'Llama 3.1',
                                                    ),
                                                    OmniChip(
                                                      label: 'Google Translate',
                                                    ),
                                                    OmniChip(label: 'MyMemory'),
                                                    OmniChip(
                                                      label: 'WebSocket',
                                                    ),
                                                    OmniChip(label: 'PyAudio'),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              const Expanded(
                                                child: _InfoCard(
                                                  icon: Icons.gavel_rounded,
                                                  title: 'License & Privacy',
                                                  content:
                                                      'Licensed for Personal Study & Learning only. Commercial use or public distribution of modified versions is strictly prohibited. Your privacy is respected; no personal data is shared.\nAll rights reserved under the original author. Access to premium features is subject to the Terms of Service.',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Right Column: Features, Support, and Links
                                        Expanded(
                                          child: Column(
                                            children: [
                                              _InfoCard(
                                                icon:
                                                    Icons.auto_awesome_rounded,
                                                title: 'Features',
                                                content: null,
                                                child: const Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    _FeatureRow(
                                                      icon: Icons.mic_rounded,
                                                      label:
                                                          'Mic & Desktop Audio Capture',
                                                    ),
                                                    _FeatureRow(
                                                      icon: Icons
                                                          .psychology_rounded,
                                                      label:
                                                          'AI Transcription: Google, Whisper, Riva',
                                                    ),
                                                    _FeatureRow(
                                                      icon: Icons
                                                          .language_rounded,
                                                      label:
                                                          'AI Translation: Llama, Google, Riva',
                                                    ),
                                                    _FeatureRow(
                                                      icon: Icons
                                                          .picture_in_picture_alt_rounded,
                                                      label:
                                                          'Mini Mode & Transparent Overlay',
                                                    ),
                                                    _FeatureRow(
                                                      icon:
                                                          Icons.history_rounded,
                                                      label:
                                                          'Searchable Caption History',
                                                    ),
                                                    _FeatureRow(
                                                      icon: Icons
                                                          .auto_fix_high_rounded,
                                                      label:
                                                          'Intelligent Context Refresh (Pro)',
                                                    ),
                                                    _FeatureRow(
                                                      icon: Icons
                                                          .cloud_done_rounded,
                                                      label:
                                                          'Cloud Sync & Auto-Updates',
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              _InfoCard(
                                                icon:
                                                    Icons.help_outline_rounded,
                                                title: 'Support & Feedback',
                                                content:
                                                    'For issues, feature requests, or general feedback, please reach out via the Help Center or submit a feedback ticket with system diagnostics.',
                                                child: Row(
                                                  children: [
                                                    _LinkButton(
                                                      icon: Icons
                                                          .support_agent_rounded,
                                                      label: 'Get Support',
                                                      url: '',
                                                      color: Colors
                                                          .lightBlueAccent,
                                                      onTap: () =>
                                                          Navigator.pushNamed(
                                                            context,
                                                            '/support',
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const Spacer(), // Pushes Links to bottom
                                              const SizedBox(height: 12),
                                              _InfoCard(
                                                icon: Icons.link_rounded,
                                                title: 'Links & Contact',
                                                content: null,
                                                child: Center(
                                                  child: Wrap(
                                                    spacing: 8,
                                                    runSpacing: 8,
                                                    alignment:
                                                        WrapAlignment.center,
                                                    children: [
                                                      _LinkButton(
                                                        icon:
                                                            Icons.code_rounded,
                                                        label: 'GitHub',
                                                        url:
                                                            'https://github.com/Marshal-GG/omni-bridge-translator',
                                                        color: Colors.white70,
                                                      ),
                                                      _LinkButton(
                                                        icon: Icons
                                                            .bug_report_rounded,
                                                        label: 'Issues',
                                                        url:
                                                            'https://github.com/Marshal-GG/omni-bridge-translator/issues',
                                                        color:
                                                            Colors.orangeAccent,
                                                      ),
                                                      _LinkButton(
                                                        icon: Icons
                                                            .email_outlined,
                                                        label: 'Email',
                                                        url:
                                                            'https://mail.google.com/mail/?view=cm&to=marshalgcom@gmail.com',
                                                        color:
                                                            Colors.tealAccent,
                                                      ),
                                                      _LinkButton(
                                                        icon:
                                                            Icons.gavel_rounded,
                                                        label: 'Terms',
                                                        url: '',
                                                        color:
                                                            Colors.blueAccent,
                                                        onTap: () =>
                                                            _LegalDialog.show(
                                                              context,
                                                              'terms_of_service',
                                                            ),
                                                      ),
                                                      _LinkButton(
                                                        icon:
                                                            Icons.gavel_rounded,
                                                        label: 'License',
                                                        url: '',
                                                        color:
                                                            Colors.amberAccent,
                                                        onTap: () =>
                                                            _LegalDialog.show(
                                                              context,
                                                              'license',
                                                            ),
                                                      ),
                                                      _LinkButton(
                                                        icon: Icons
                                                            .privacy_tip_rounded,
                                                        label: 'Privacy',
                                                        url: '',
                                                        color:
                                                            Colors.purpleAccent,
                                                        onTap: () =>
                                                            _LegalDialog.show(
                                                              context,
                                                              'privacy_policy',
                                                            ),
                                                      ),
                                                      _LinkButton(
                                                        icon: Icons
                                                            .system_update_alt_rounded,
                                                        label: 'Test Update',
                                                        url: '',
                                                        color: Colors.redAccent,
                                                        onTap: () =>
                                                            Navigator.pushNamed(
                                                              context,
                                                              AppRouter
                                                                  .forceUpdate,
                                                            ),
                                                      ),
                                                      _LinkButton(
                                                        icon: Icons.rocket_launch_rounded,
                                                        label: 'Test Splash',
                                                        url: '',
                                                        color: Colors.lightGreenAccent,
                                                        onTap: () => _showSplashPreview(context),
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
                                  ),
                                  const SizedBox(height: 24),
                                  if (state.version.isNotEmpty) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.03,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.05,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'Version ${state.version}',
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 10,
                                          letterSpacing: 0.8,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  const OmniCopyright(),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? content;
  final Widget? child;

  const _InfoCard({
    required this.icon,
    required this.title,
    this.content,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.tealAccent),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          if (content != null) ...[
            const SizedBox(height: 10),
            Text(
              content!,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ],
          if (child != null) ...[const SizedBox(height: 12), child!],
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 13, color: Colors.tealAccent.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String url;
  final Color color;
  final VoidCallback? onTap;

  const _LinkButton({
    required this.icon,
    required this.label,
    required this.url,
    required this.color,
    this.onTap,
  });

  @override
  State<_LinkButton> createState() => _LinkButtonState();
}

class _LinkButtonState extends State<_LinkButton> {
  bool _hovered = false;

  Future<void> _launch() async {
    final uri = Uri.parse(widget.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap ?? _launch,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.color.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.4)
                  : Colors.white12,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14, color: widget.color),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: _hovered ? widget.color : Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalDialog extends StatelessWidget {
  final String documentId;

  const _LegalDialog({required this.documentId});

  static void show(BuildContext context, String documentId) {
    showDialog(
      context: context,
      builder: (context) => _LegalDialog(documentId: documentId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = documentId == 'terms_of_service'
        ? 'Terms of Service'
        : 'Privacy Policy';

    return Dialog(
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              _buildHeader(context, title),
              const Divider(height: 1, color: Colors.white12),
              Expanded(child: _buildBody()),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            documentId == 'terms_of_service'
                ? Icons.gavel_rounded
                : Icons.privacy_tip_rounded,
            color: Colors.tealAccent,
            size: 16,
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close, color: Colors.white38, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return FutureBuilder<DocumentSnapshot>(
      future: AuthRemoteDataSource.instance.firestore
          .collection(FirebasePaths.legal)
          .doc(documentId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.tealAccent,
              strokeWidth: 2,
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading: ${snapshot.error}',
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(
            child: Text(
              'Document not found.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final content = data['content'] as String? ?? '';

        return Padding(
          padding: const EdgeInsets.all(12),
          child: Card(
            color: Colors.white.withValues(alpha: 0.04),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: const BorderSide(color: Colors.white12),
            ),
            margin: EdgeInsets.zero,
            elevation: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Markdown(
                data: content,
                selectable: true,
                padding: const EdgeInsets.all(16),
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Inter',
                    fontSize: 12,
                    height: 1.7,
                    letterSpacing: 0.1,
                  ),
                  h1: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 2.2,
                    letterSpacing: 0.3,
                  ),
                  h2: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 2,
                    letterSpacing: 0.2,
                  ),
                  h3: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.8,
                  ),
                  strong: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  em: const TextStyle(
                    color: Colors.white54,
                    fontFamily: 'Inter',
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                  listBullet: const TextStyle(
                    color: Colors.tealAccent,
                    fontFamily: 'Inter',
                    fontSize: 12,
                  ),
                  blockquoteDecoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    border: const Border(
                      left: BorderSide(color: Colors.tealAccent, width: 3),
                    ),
                  ),
                  code: TextStyle(
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    color: Colors.tealAccent,
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                  horizontalRuleDecoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white12)),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Colors.tealAccent),
            ),
          ),
        ],
      ),
    );
  }
}

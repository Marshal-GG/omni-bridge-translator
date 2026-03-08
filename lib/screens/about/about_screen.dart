import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/services/update_service.dart';
import '../../core/window_manager.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';
  UpdateStatus _updateStatus = UpdateStatus.idle;
  UpdateResult? _updateResult;
  final GlobalKey _contentKey = GlobalKey();
  double _lastHeight = 0;

  Future<void> _adjustWindowSize() async {
    if (!mounted) return;
    final context = _contentKey.currentContext;
    if (context != null) {
      final RenderBox box = context.findRenderObject() as RenderBox;
      final contentHeight = box.size.height;
      final targetHeight = contentHeight + 35; // 32 (header) + 1 (divider) + 2 (window borders)
      if ((_lastHeight - targetHeight).abs() > 1) {
        _lastHeight = targetHeight;
        await windowManager.setSize(Size(1140, targetHeight));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    setToAboutPosition();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
    // Reflect any background check that already ran
    if (UpdateNotifier.instance.value) {
      _updateStatus = UpdateStatus.available;
      _updateResult = UpdateResult(
        status: UpdateStatus.available,
        latestVersion: UpdateNotifier.instance.latestVersion,
        releaseUrl: UpdateNotifier.instance.releaseUrl,
      );
    }
  }

  Future<void> _checkForUpdate() async {
    setState(() => _updateStatus = UpdateStatus.checking);
    final result = await UpdateService.instance.checkForUpdate();
    if (!mounted) return;
    setState(() {
      _updateResult = result;
      _updateStatus = result.status;
    });
    if (result.status == UpdateStatus.available) {
      UpdateNotifier.instance.setAvailable(
        result.latestVersion!,
        result.releaseUrl!,
      );
    }
  }

  Future<void> _openRelease() async {
    final url = _updateResult?.releaseUrl ?? '';
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _adjustWindowSize());
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WindowBorder(
        color: Colors.white12,
        width: 1,
        child: Container(
          color: const Color(0xFF121212),
          child: Column(
            children: [
              _buildHeader(context),
              const Divider(height: 1, color: Colors.white10),
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
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 28,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // ── Branding ───────────────────────────────────
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Logo
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Image.asset(
                                          'assets/icon.png',
                                          width: 86,
                                          height: 86,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Omni Bridge',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const Text(
                                            'Live AI Translator',
                                            style: TextStyle(
                                              color: Colors.tealAccent,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white10,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              _version.isNotEmpty
                                                  ? 'Version $_version'
                                                  : '',
                                              style: const TextStyle(
                                                color: Colors.white38,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          // ── Check for Updates ──────────────────
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Outlined button
                                              SizedBox(
                                                height: 26,
                                                child: OutlinedButton(
                                                  onPressed:
                                                      _updateStatus ==
                                                          UpdateStatus.checking
                                                      ? null
                                                      : _checkForUpdate,
                                                  style: OutlinedButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 0,
                                                        ),
                                                    side: BorderSide(
                                                      color:
                                                          _updateStatus ==
                                                              UpdateStatus.checking
                                                          ? Colors.white12
                                                          : Colors.tealAccent
                                                                .withValues(
                                                                  alpha: 0.4,
                                                                ),
                                                    ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(6),
                                                    ),
                                                    foregroundColor:
                                                        Colors.tealAccent,
                                                  ),
                                                  child:
                                                      _updateStatus ==
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
                                                          _updateStatus ==
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
                                              if (_updateStatus !=
                                                      UpdateStatus.idle &&
                                                  _updateStatus !=
                                                      UpdateStatus.checking) ...[
                                                const SizedBox(height: 4),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    if (_updateStatus ==
                                                        UpdateStatus.upToDate)
                                                      const Icon(
                                                        Icons
                                                            .check_circle_outline_rounded,
                                                        size: 11,
                                                        color: Colors.tealAccent,
                                                      )
                                                    else if (_updateStatus ==
                                                        UpdateStatus.available)
                                                      const Icon(
                                                        Icons.upgrade_rounded,
                                                        size: 11,
                                                        color: Colors.orangeAccent,
                                                      )
                                                    else if (_updateStatus ==
                                                        UpdateStatus.error)
                                                      const Icon(
                                                        Icons.error_outline_rounded,
                                                        size: 11,
                                                        color: Colors.redAccent,
                                                      ),
                                                    const SizedBox(width: 4),
                                                    if (_updateStatus ==
                                                        UpdateStatus.upToDate)
                                                      const Text(
                                                        'Up to date',
                                                        style: TextStyle(
                                                          color: Colors.tealAccent,
                                                          fontSize: 10,
                                                        ),
                                                      )
                                                    else if (_updateStatus ==
                                                        UpdateStatus.available)
                                                      GestureDetector(
                                                        onTap: _openRelease,
                                                        child: Text(
                                                          'v${_updateResult?.latestVersion} available — Download',
                                                          style: const TextStyle(
                                                            color:
                                                                Colors.orangeAccent,
                                                            fontSize: 10,
                                                            decoration: TextDecoration
                                                                .underline,
                                                            decorationColor:
                                                                Colors.orangeAccent,
                                                          ),
                                                        ),
                                                      )
                                                    else if (_updateStatus ==
                                                        UpdateStatus.error)
                                                      Text(
                                                        _updateResult?.errorMessage ??
                                                            'Check failed.',
                                                        style: const TextStyle(
                                                          color: Colors.redAccent,
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),

                                  // ── Row 1: About | Features ────────────────────
                                  IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: _InfoCard(
                                            icon: Icons.info_outline_rounded,
                                            title: 'About',
                                            content:
                                                'Omni Bridge provides real-time AI-powered live captions and translations directly on your Windows desktop. Capture any audio — system output or microphone — and see it transcribed and translated instantly in a floating, always-on-top overlay.',
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _InfoCard(
                                            icon: Icons.auto_awesome_rounded,
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
                                                  icon: Icons.psychology_rounded,
                                                  label:
                                                      'AI Transcription: Google, Whisper, Riva',
                                                ),
                                                _FeatureRow(
                                                  icon: Icons.language_rounded,
                                                  label:
                                                      'AI Translation: Llama, Google, Riva, MyMemory',
                                                ),
                                                _FeatureRow(
                                                  icon: Icons
                                                      .picture_in_picture_alt_rounded,
                                                  label:
                                                      'Transparent Always-On-Top Overlay',
                                                ),
                                                _FeatureRow(
                                                  icon: Icons.history_rounded,
                                                  label:
                                                      'Full Session Caption History',
                                                ),
                                                _FeatureRow(
                                                  icon: Icons.cloud_done_rounded,
                                                  label:
                                                      'Synced Settings via Firebase',
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // ── Row 2: Built With | Support + Legal ────────
                                  IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: _InfoCard(
                                            icon: Icons.code_rounded,
                                            title: 'Built With',
                                            content: null,
                                            child: const Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: [
                                                _Chip('Flutter'),
                                                _Chip('Python FastAPI'),
                                                _Chip('Firebase'),
                                                _Chip('NVIDIA Riva'),
                                                _Chip('OpenAI Whisper'),
                                                _Chip('Llama / NIM'),
                                                _Chip('Google Translate'),
                                                _Chip('MyMemory'),
                                                _Chip('WebSocket'),
                                                _Chip('PyAudio WPATCH'),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: const [
                                              _InfoCard(
                                                icon: Icons.help_outline_rounded,
                                                title: 'Support & Feedback',
                                                content:
                                                    'For issues, feature requests, or general feedback, please reach out via the project repository or contact the developer directly.',
                                              ),
                                              SizedBox(height: 12),
                                              _InfoCard(
                                                icon: Icons.gavel_rounded,
                                                title: 'License & Privacy',
                                                content:
                                                    'This software is provided for personal use. API keys are stored locally. Analytics are anonymous. We do not sell or share your data.',
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // ── Row 3: Links & Contact (full width) ────────
                                  _InfoCard(
                                    icon: Icons.link_rounded,
                                    title: 'Links & Contact',
                                    content: null,
                                    child: Center(
                                      child: Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        alignment: WrapAlignment.center,
                                        children: [
                                          _LinkButton(
                                            icon: Icons.code_rounded,
                                            label: 'GitHub Repository',
                                            url:
                                                'https://github.com/Marshal-GG/omni-bridge-translator',
                                            color: Colors.white70,
                                          ),
                                          _LinkButton(
                                            icon: Icons.bug_report_rounded,
                                            label: 'Report an Issue',
                                            url:
                                                'https://github.com/Marshal-GG/omni-bridge-translator/issues',
                                            color: Colors.orangeAccent,
                                          ),
                                          _LinkButton(
                                            icon: Icons.star_rounded,
                                            label: 'Star on GitHub',
                                            url:
                                                'https://github.com/Marshal-GG/omni-bridge-translator',
                                            color: Colors.yellowAccent,
                                          ),
                                          _LinkButton(
                                            icon: Icons.email_outlined,
                                            label: 'Email Developer',
                                            url:
                                                'https://mail.google.com/mail/?view=cm&to=marshalgcom@gmail.com',
                                            color: Colors.tealAccent,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 24),
                                  const Text(
                                    '© 2026 Omni Bridge. All rights reserved.',
                                    style: TextStyle(
                                      color: Colors.white24,
                                      fontSize: 11,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
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
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.arrow_back_rounded,
                size: 15,
                color: Colors.white38,
              ),
              tooltip: 'Back to Translator',
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.info_outline_rounded,
            size: 14,
            color: Colors.white38,
          ),
          const SizedBox(width: 8),
          const Text(
            'About Omni Bridge',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(child: MoveWindow()),
          MinimizeWindowButton(
            colors: WindowButtonColors(iconNormal: Colors.white38),
          ),
          CloseWindowButton(
            colors: WindowButtonColors(
              iconNormal: Colors.white38,
              mouseOver: Colors.redAccent,
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
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

class _Chip extends StatelessWidget {
  final String label;

  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.tealAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.tealAccent,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _LinkButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String url;
  final Color color;

  const _LinkButton({
    required this.icon,
    required this.label,
    required this.url,
    required this.color,
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
        onTap: _launch,
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

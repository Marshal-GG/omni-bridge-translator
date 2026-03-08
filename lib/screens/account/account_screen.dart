import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/subscription_service.dart';
import '../../core/window_manager.dart';
import 'components/account_header.dart';
import 'components/account_avatar.dart';
import 'components/account_name_editor.dart';
import 'components/account_email_info.dart';
import 'components/account_button.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _nameController = TextEditingController();
  bool _isSaving = false;
  String? _message;
  bool _messageIsError = false;
  String _version = '1.0.0';

  @override
  void initState() {
    super.initState();
    setToAccountPosition();
    final user = AuthService.instance.currentUser.value;
    _nameController.text = user?.displayName ?? '';
    
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;
    setState(() {
      _isSaving = true;
      _message = null;
    });
    try {
      await AuthService.instance.updateDisplayName(newName);
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _message = 'Display name updated!';
        _messageIsError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _message = 'Failed to update: $e';
        _messageIsError = true;
      });
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Sign Out?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'You will be returned to the login screen.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final nav = Navigator.of(context);
      await AuthService.instance.signOut();
      await setToLoginPosition();
      nav.pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  Widget _buildPlannedItem(String label, bool isSoon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            isSoon ? Icons.auto_mode_rounded : Icons.radio_button_unchecked_rounded,
            size: 14,
            color: isSoon ? Colors.orangeAccent : Colors.white24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isSoon ? Colors.white.withValues(alpha: 0.8) : Colors.white38,
                fontSize: 12,
                fontWeight: isSoon ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
          if (isSoon)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'SOON',
                style: TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser.value;
    final isAnon = user?.isAnonymous ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WindowBorder(
        color: Colors.white10,
        width: 1,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF161616),
                Color(0xFF0F0F0F),
              ],
            ),
          ),
          child: Column(
            children: [
              // ── Draggable Header ──────────────────────────────────────────
              buildAccountHeader(
                onBack: () {
                  Navigator.of(context).pop();
                },
              ),
              const Divider(height: 1, color: Colors.white10),

              // ── Content ───────────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Center(
                    child: SizedBox(
                      width: 420,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 32,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ── Avatar Section ──────────────────────────────
                            buildAccountAvatar(user, isAnon),
                            const SizedBox(height: 32),

                            if (!isAnon) ...[
                              // ── Profile Info Card ──────────────────────────
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.person_outline_rounded, size: 16, color: Colors.tealAccent),
                                          SizedBox(width: 8),
                                          Text(
                                            'PROFILE INFORMATION',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      buildAccountNameEditor(
                                        controller: _nameController,
                                        isSaving: _isSaving,
                                        message: _message,
                                        messageIsError: _messageIsError,
                                        onSave: _updateName,
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        child: Divider(height: 1, color: Colors.white10),
                                      ),
                                      buildAccountEmailInfo(user),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // ── Plan Details Card ──────────────────────────
                              StreamBuilder<SubscriptionStatus>(
                                stream: SubscriptionService.instance.statusStream,
                                initialData: SubscriptionService.instance.currentStatus,
                                builder: (context, snapshot) {
                                  final status = snapshot.data;
                                  if (status == null) return const SizedBox.shrink();

                                  final tierName = status.tier.name.toUpperCase();
                                  final isUnlimited = status.isUnlimited;
                                  final progress = status.progress;

                                  return Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.tealAccent.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons.auto_awesome_rounded,
                                                  color: Colors.tealAccent,
                                                  size: 18,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '$tierName PLAN',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.bold,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      isUnlimited
                                                          ? 'Unlimited character translation'
                                                          : '${status.dailyCharsUsed} / ${status.dailyLimit} chars used today',
                                                      style: const TextStyle(
                                                        color: Colors.white54,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (!isUnlimited) ...[
                                            const SizedBox(height: 16),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: progress.clamp(0.0, 1.0),
                                                backgroundColor: Colors.white.withValues(alpha: 0.05),
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  progress >= 0.9
                                                      ? Colors.redAccent
                                                      : Colors.tealAccent,
                                                ),
                                                minHeight: 4,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 16),
                                          SizedBox(
                                            width: double.infinity,
                                            height: 36,
                                            child: OutlinedButton(
                                              onPressed: () {
                                                Navigator.pushNamed(context, '/subscription');
                                              },
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(
                                                  color: Colors.tealAccent.withValues(alpha: 0.3),
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: const Text(
                                                'Manage Subscription',
                                                style: TextStyle(
                                                  color: Colors.tealAccent,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),

                              // ── DEBUG: Plan Switcher ───────────────────────
                              if (kDebugMode)
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(Icons.bug_report_rounded, size: 16, color: Colors.redAccent),
                                            SizedBox(width: 8),
                                            Text(
                                              'DEBUG: CHANGE PLAN',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: SubscriptionTier.values.map((tier) {
                                            return SizedBox(
                                              height: 32,
                                              child: ActionChip(
                                                label: Text(
                                                  tier.name.toUpperCase(),
                                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                                backgroundColor: Colors.white.withValues(alpha: 0.05),
                                                onPressed: () => SubscriptionService.instance.setTierDebug(tier),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (kDebugMode) const SizedBox(height: 12),

                              // ── Planned Features Card (Todo) ───────────────
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.upcoming_rounded, size: 16, color: Colors.orangeAccent),
                                          SizedBox(width: 8),
                                          Text(
                                            'PLANNED FEATURES',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _buildPlannedItem('Audio Translation & Text-to-Speech', true),
                                      _buildPlannedItem('PDF & Image Document Support', false),
                                      _buildPlannedItem('Custom Vocabulary & Glossary', false),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],

                            if (isAnon) const SizedBox(height: 24),

                            // ── Footer Actions ────────────────────────────
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: AccountButton(
                                icon: Icons.logout_rounded,
                                label: 'Sign Out',
                                onPressed: _signOut,
                                isDanger: true,
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            _VersionChip(label: 'v$_version'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VersionChip extends StatelessWidget {
  final String label;

  const _VersionChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        'OMNI BRIDGE $label'.toUpperCase(),
        style: const TextStyle(
          color: Colors.white24,
          fontSize: 8,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

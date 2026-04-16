import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:omni_bridge/core/theme/app_theme.dart';
import 'package:omni_bridge/core/widgets/omni_version_chip.dart';
import 'package:omni_bridge/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:omni_bridge/features/auth/presentation/screens/account/components/account_header.dart';
import 'package:omni_bridge/features/auth/presentation/screens/account/components/account_button.dart';
import 'package:omni_bridge/features/shell/presentation/widgets/app_dashboard_shell.dart';
import 'package:omni_bridge/core/navigation/app_router.dart';

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

  @override
  void initState() {
    super.initState();
    final user = AuthRemoteDataSource.instance.currentUser.value;
    _nameController.text = user?.displayName ?? '';
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
      await AuthRemoteDataSource.instance.updateDisplayName(newName);
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
        backgroundColor: AppColors.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Sign Out?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'You will be returned to the login screen.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await AuthRemoteDataSource.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthRemoteDataSource.instance.currentUser.value;
    final isAnon = user?.isAnonymous ?? false;

    return AppDashboardShell(
      currentRoute: AppRouter.account,
      header: buildAccountHeader(
        context,
        onBack: () => Navigator.of(context).pop(),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 28,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Profile Hero ──────────────────────────────────
                  _ProfileHero(user: user, isAnon: isAnon),
                  const SizedBox(height: 24),

                  if (!isAnon) ...[
                    // ── Profile card (name + sessions) ────────────
                    _ProfileCard(
                      user: user!,
                      nameController: _nameController,
                      isSaving: _isSaving,
                      message: _message,
                      messageIsError: _messageIsError,
                      onSave: _updateName,
                    ),
                    const SizedBox(height: 28),
                  ],

                  if (isAnon) const SizedBox(height: 24),

                  // ── Sign Out ──────────────────────────────────────
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
                  const OmniVersionChip(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

}

// ── Compact name editor ───────────────────────────────────────────────────────

// ── Profile card (name + sessions) ───────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final User user;
  final TextEditingController nameController;
  final bool isSaving;
  final String? message;
  final bool messageIsError;
  final VoidCallback onSave;

  const _ProfileCard({
    required this.user,
    required this.nameController,
    required this.isSaving,
    required this.message,
    required this.messageIsError,
    required this.onSave,
  });

  String _fmt(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('MMM d, y · h:mm a').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Profile section ──
          _SectionLabel(icon: Icons.person_outline_rounded, label: 'PROFILE'),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Display name',
                style: TextStyle(
                  color: AppColors.textDisabled,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    controller: nameController,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Your name',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 0,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: isSaving ? null : onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentTeal,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              style: TextStyle(
                color: messageIsError ? Colors.redAccent : AppColors.accentTeal,
                fontSize: 11,
              ),
            ),
          ],

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Colors.white10),
          ),

          // ── Session section ──
          _SectionLabel(icon: Icons.devices_rounded, label: 'SESSION'),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.login_rounded,
            label: 'Last sign-in',
            value: _fmt(user.metadata.lastSignInTime),
          ),
          const SizedBox(height: 6),
          _InfoRow(
            icon: Icons.calendar_today_rounded,
            label: 'Account created',
            value: _fmt(user.metadata.creationTime),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: AppColors.accentTeal),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textDisabled,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: AppColors.textDisabled),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Profile hero ──────────────────────────────────────────────────────────────

String _providerLabel(bool isAnon, User? user) {
  if (isAnon) return 'Guest Mode';
  final id = user?.providerData.firstOrNull?.providerId ?? '';
  return switch (id) {
    'google.com' => 'Google Account',
    'password' => 'Email Account',
    _ => id.isNotEmpty ? id : 'Signed In',
  };
}

class _ProfileHero extends StatelessWidget {
  final User? user;
  final bool isAnon;

  const _ProfileHero({required this.user, required this.isAnon});

  @override
  Widget build(BuildContext context) {
    final photoUrl = user?.photoURL;
    final name = isAnon
        ? 'Guest User'
        : (user?.displayName?.isNotEmpty == true ? user!.displayName! : 'No Name');
    final email = user?.email ?? '';
    final initials = name
        .trim()
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return Column(
      children: [
        // Avatar
        Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.accentTeal.withValues(alpha: 0.25),
                  AppColors.accentTeal.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: AppColors.accentTeal.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: ClipOval(
              child: photoUrl != null && photoUrl.startsWith('http')
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _AvatarInitials(initials: initials),
                    )
                  : _AvatarInitials(initials: initials),
            ),
          ),
          const SizedBox(height: 14),

          // Name
          Text(
            name,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),

          // Email
          if (email.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              email,
              style: const TextStyle(
                color: AppColors.textDisabled,
                fontSize: 12,
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Provider badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accentTeal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.accentTeal.withValues(alpha: 0.18),
              ),
            ),
            child: Text(
              _providerLabel(isAnon, user).toUpperCase(),
              style: const TextStyle(
                color: AppColors.accentTeal,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      );
  }
}

class _AvatarInitials extends StatelessWidget {
  final String initials;
  const _AvatarInitials({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials.isNotEmpty ? initials : '?',
        style: const TextStyle(
          color: AppColors.accentTeal,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omni_bridge/core/widgets/omni_version_chip.dart';
import 'package:omni_bridge/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:omni_bridge/features/subscription/data/datasources/subscription_remote_datasource.dart';

import 'package:omni_bridge/features/usage/domain/repositories/usage_repository.dart';
import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';
import 'package:omni_bridge/core/di/di.dart';

import 'package:omni_bridge/features/auth/presentation/screens/account/components/account_header.dart';
import 'package:omni_bridge/features/auth/presentation/screens/account/components/account_avatar.dart';
import 'package:omni_bridge/features/auth/presentation/screens/account/components/account_name_editor.dart';
import 'package:omni_bridge/features/auth/presentation/screens/account/components/account_email_info.dart';
import 'package:omni_bridge/features/auth/presentation/screens/account/components/account_button.dart';
import 'package:omni_bridge/features/auth/presentation/screens/account/components/admin_panel.dart';
import 'package:omni_bridge/core/widgets/omni_window_layout.dart';
import 'package:omni_bridge/core/widgets/omni_progress_bar.dart';
import 'package:omni_bridge/core/widgets/omni_card.dart';

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
  final _formatter = NumberFormat('#,###');

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
      await AuthRemoteDataSource.instance.signOut();
    }
  }

  Widget _buildPlannedItem(String label, bool isSoon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            isSoon
                ? Icons.auto_mode_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 14,
            color: isSoon ? Colors.orangeAccent : Colors.white24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isSoon
                    ? Colors.white.withValues(alpha: 0.8)
                    : Colors.white38,
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
    final user = AuthRemoteDataSource.instance.currentUser.value;
    final isAnon = user?.isAnonymous ?? false;

    return OmniWindowLayout(
      child: Column(
        children: [
          // ── Draggable Header ──────────────────────────────────────────
          buildAccountHeader(
            context,
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
                          OmniCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.person_outline_rounded,
                                      size: 16,
                                      color: Colors.tealAccent,
                                    ),
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
                                  child: Divider(
                                    height: 1,
                                    color: Colors.white10,
                                  ),
                                ),
                                buildAccountEmailInfo(user),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ── Plan Details Card ──────────────────────────
                          StreamBuilder<QuotaStatus>(
                            stream: sl<UsageRepository>().quotaStatusStream,
                            initialData:
                                sl<UsageRepository>().currentQuotaStatus,
                            builder: (context, snapshot) {
                              final status = snapshot.data;
                              if (status == null) {
                                return const SizedBox.shrink();
                              }

                              final tierName = SubscriptionRemoteDataSource
                                  .instance
                                  .getNameForTier(status.tier)
                                  .toUpperCase();
                              final isUnlimited = status.isUnlimited;
                              final progress = status.progress;

                              return OmniCard(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.tealAccent.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
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
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
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
                                                    ? 'Unlimited token translation'
                                                    : '${_formatter.format(status.dailyTokensUsed)} / ${_formatter.format(status.dailyLimit)} tokens used today',
                                                style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  _UsageBadge(
                                                    label: 'WEEKLY',
                                                    value: _formatter.format(
                                                      status.weeklyTokensUsed,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  _UsageBadge(
                                                    label: 'MONTHLY',
                                                    value: _formatter.format(
                                                      status.monthlyTokensUsed,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  _UsageBadge(
                                                    label: 'LIFETIME',
                                                    value: _formatter.format(
                                                      status.lifetimeTokensUsed,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (!isUnlimited) ...[
                                      const SizedBox(height: 16),
                                      OmniProgressBar(
                                        progress: progress,
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.05),
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: SizedBox(
                                            height: 36,
                                            child: OutlinedButton(
                                              onPressed: () {
                                                Navigator.pushNamed(
                                                  context,
                                                  '/usage',
                                                );
                                              },
                                              child: const Text(
                                                'Detailed Usage',
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: SizedBox(
                                            height: 36,
                                            child: OutlinedButton(
                                              onPressed: () {
                                                Navigator.pushNamed(
                                                  context,
                                                  '/subscription',
                                                );
                                              },
                                              child: const Text('Manage Plan'),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          const AdminPanel(),

                          // ── Planned Features Card (Todo) ───────────────
                          OmniCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.upcoming_rounded,
                                      size: 16,
                                      color: Colors.orangeAccent,
                                    ),
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
                                _buildPlannedItem(
                                  'Audio Translation & Text-to-Speech',
                                  true,
                                ),
                                _buildPlannedItem(
                                  'PDF & Image Document Support',
                                  false,
                                ),
                                _buildPlannedItem(
                                  'Custom Vocabulary & Glossary',
                                  false,
                                ),
                              ],
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
                        const OmniVersionChip(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageBadge extends StatelessWidget {
  final String label;
  final String value;

  const _UsageBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.tealAccent,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

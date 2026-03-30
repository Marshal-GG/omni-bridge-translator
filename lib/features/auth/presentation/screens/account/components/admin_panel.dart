import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:omni_bridge/core/widgets/omni_tinted_button.dart';
import 'package:omni_bridge/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:omni_bridge/features/subscription/data/datasources/subscription_remote_datasource.dart';
import 'package:omni_bridge/core/widgets/omni_search_bar.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  String _adminUserSearch = '';
  String? _selectedUserUid;
  String? _selectedUserName;
  bool? _isAdmin; // null = loading

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    final user = AuthRemoteDataSource.instance.auth.currentUser;
    if (user == null || user.email == null) {
      if (mounted) setState(() => _isAdmin = false);
      return;
    }
    try {
      final doc = await AuthRemoteDataSource.instance.firestore
          .collection('system')
          .doc('admins')
          .get();
      final emails = List<String>.from(doc.data()?['emails'] ?? []);
      if (mounted) setState(() => _isAdmin = emails.contains(user.email));
    } catch (_) {
      if (mounted) setState(() => _isAdmin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAdmin != true) return const SizedBox.shrink();

    return Column(
      children: [
        // ── ADMIN: Identity / Admin Emails ──────────────────────────
        const _AdminIdentitySection(),
        const SizedBox(height: 12),

        // ── ADMIN: User Selection & Plan Manager ─────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.manage_accounts_rounded,
                      size: 16,
                      color: Colors.tealAccent,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'MANAGE PLANS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.tealAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                OmniSearchBar(
                  hintText: 'Search by Name or Email...',
                  onChanged: (val) =>
                      setState(() => _adminUserSearch = val.trim()),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FutureBuilder(
                    future: AuthRemoteDataSource.instance.firestore
                        .collection('users')
                        .get(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Error: ${snapshot.error}',
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 11,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () => setState(() {}),
                                  child: const Text(
                                    'Retry',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data!.docs.where((doc) {
                        final data = doc.data();
                        final name = (data['displayName'] ?? '')
                            .toString()
                            .toLowerCase();
                        final email = (data['email'] ?? '')
                            .toString()
                            .toLowerCase();
                        final q = _adminUserSearch.toLowerCase();
                        return q.isEmpty ||
                            name.contains(q) ||
                            email.contains(q);
                      }).toList();

                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'No users found',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white54,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => setState(() {}),
                                child: const Text(
                                  'Refresh List',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data();
                          final uid = data['uid'] ?? 'unknown';
                          final name = data['displayName'] ?? 'No Name';
                          final email = data['email'] ?? 'No Email';
                          final isSelected = _selectedUserUid == uid;
                          final tier =
                              data['tier'] ??
                              SubscriptionRemoteDataSource.instance.defaultTier;

                          return ListTile(
                            dense: true,
                            selected: isSelected,
                            selectedTileColor: Colors.white12,
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isSelected
                                          ? Colors.tealAccent
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.tealAccent.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.tealAccent.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    tier.toString().toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.tealAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              email,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white54,
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                _selectedUserUid = uid;
                                _selectedUserName = name;
                              });
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                if (_selectedUserUid != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Set Plan for $_selectedUserName:',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.tealAccent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<int>(
                    valueListenable:
                        SubscriptionRemoteDataSource.instance.configNotifier,
                    builder: (context, _, _) {
                      final plans = SubscriptionRemoteDataSource.instance.availablePlans;
                      if (plans.isEmpty) {
                        return const Text(
                          'No plans loaded – seed config first',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        );
                      }
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: plans.map((plan) {
                          final tier = plan.id;
                          return SizedBox(
                            height: 32,
                            child: ActionChip(
                              label: Text(
                                SubscriptionRemoteDataSource.instance
                                    .getNameForTier(tier)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.05,
                              ),
                              onPressed: () {
                                SubscriptionRemoteDataSource.instance
                                    .setTierForOtherUser(
                                      _selectedUserUid!,
                                      tier,
                                    );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Plan updated for $_selectedUserName',
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── ADMIN: System Config Seeder ────────────────────────────
        const _SystemConfigSection(),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ── System Config Section ───────────────────────────────────────────────────
// Seeds the system/monetization document with tier definitions,
// model overrides, announcements, upgrade prompts, and app version control.

class _SystemConfigSection extends StatefulWidget {
  const _SystemConfigSection();

  @override
  State<_SystemConfigSection> createState() => _SystemConfigSectionState();
}

class _SystemConfigSectionState extends State<_SystemConfigSection> {
  bool _seeding = false;
  bool _updatingPoll = false;
  String? _lastResult;
  late final _pollController = TextEditingController(
    text: SubscriptionRemoteDataSource.instance.pollIntervalSeconds.toString(),
  );

  @override
  void initState() {
    super.initState();
    SubscriptionRemoteDataSource.instance.configNotifier.addListener(_onConfigChanged);
  }

  void _onConfigChanged() {
    if (!mounted) return;
    final newValue = SubscriptionRemoteDataSource.instance.pollIntervalSeconds.toString();
    if (_pollController.text != newValue && !_updatingPoll) {
      setState(() {
        _pollController.text = newValue;
      });
    }
  }

  @override
  void dispose() {
    SubscriptionRemoteDataSource.instance.configNotifier.removeListener(_onConfigChanged);
    _pollController.dispose();
    super.dispose();
  }

  static const Map<String, dynamic> _seedData = {
    // ── Tier Order (first = default/free tier) ────────────────────────
    'order': ['free', 'trial', 'pro', 'enterprise'],
    'popular': 'pro',

    // ── Tier Definitions ──────────────────────────────────────────────
    'tiers': {
      'free': {
        'name': 'Free',
        'price': '₹0',
        'description': 'Basic translation for casual use',
        'display_features': [
          'Google & MyMemory translation',
          'Desktop audio capture',
          '5,000 tokens/day',
        ],
        'allowed_transcription_models': ['online'],
        'allowed_translation_models': ['google', 'mymemory'],
        'features': {
          'mic_audio': false,
          'history_enabled': false,
          'caption_retention_days': 0,
          'simultaneous_sessions': 1,
        },
        'quotas': {'daily_tokens': 5000, 'monthly_tokens': 0},
        'engine_limits': {},
        'rate_limits': {'requests_per_minute': 20, 'concurrent_sessions': 1},
      },
      'trial': {
        'name': 'Trial',
        'price': '₹49',
        'description': 'One-time 3-hour pass — full engine access',
        'is_trial': true,
        'trial_duration_hours': 3,
        'display_features': [
          'All translation & transcription engines',
          'Microphone + desktop audio',
          '15,000 tokens for 3 hours',
          'One-time per account',
        ],
        'allowed_transcription_models': [
          'online',
          'whisper-tiny',
          'whisper-base',
          'whisper-small',
          'whisper-medium',
          'riva',
        ],
        'allowed_translation_models': [
          'google',
          'mymemory',
          'google_api',
          'riva',
          'llama',
        ],
        'features': {
          'mic_audio': true,
          'history_enabled': false,
          'caption_retention_days': 0,
          'simultaneous_sessions': 1,
        },
        'quotas': {'daily_tokens': -1, 'monthly_tokens': 15000},
        'engine_limits': {'google_api': 6000, 'riva': 6000, 'llama': 6000},
        'rate_limits': {'requests_per_minute': 60, 'concurrent_sessions': 1},
      },
      'pro': {
        'name': 'Pro',
        'price': '\u20B9799/mo',
        'description': 'All engines with generous limits',
        'display_features': [
          'All translation engines',
          'Whisper transcription (tiny–small)',
          'Microphone + desktop audio',
          'Caption history (7 days)',
          '25,000 tokens/day',
        ],
        'allowed_transcription_models': [
          'online',
          'whisper-tiny',
          'whisper-base',
          'whisper-small',
        ],
        'allowed_translation_models': [
          'google',
          'mymemory',
          'google_api',
          'riva',
          'llama',
        ],
        'features': {
          'mic_audio': true,
          'history_enabled': true,
          'caption_retention_days': 7,
          'simultaneous_sessions': 2,
        },
        'quotas': {'daily_tokens': 25000, 'monthly_tokens': 250000},
        'engine_limits': {
          'google_api': 100000,
          'riva': 100000,
          'llama': 150000,
        },
        'rate_limits': {'requests_per_minute': 60, 'concurrent_sessions': 2},
      },
      'enterprise': {
        'name': 'Enterprise',
        'price': '\u20B92,499/mo',
        'description': 'Maximum capacity for power users',
        'display_features': [
          'Everything in Pro',
          'Whisper medium + Riva transcription',
          'Caption history (30 days)',
          'Up to 5 simultaneous sessions',
          '75,000 tokens/day',
        ],
        'allowed_transcription_models': [
          'online',
          'whisper-tiny',
          'whisper-base',
          'whisper-small',
          'whisper-medium',
          'riva',
        ],
        'allowed_translation_models': [
          'google',
          'mymemory',
          'google_api',
          'riva',
          'llama',
        ],
        'features': {
          'mic_audio': true,
          'history_enabled': true,
          'caption_retention_days': 30,
          'simultaneous_sessions': 5,
        },
        'quotas': {'daily_tokens': 75000, 'monthly_tokens': 750000},
        'engine_limits': {
          'google_api': 300000,
          'riva': 300000,
          'llama': 500000,
        },
        'rate_limits': {'requests_per_minute': 120, 'concurrent_sessions': 5},
      },
    },

    // ── Payment Links (replace with real Razorpay URLs) ────────────────
    'payment_links': {'trial': '', 'pro': '', 'enterprise': ''},

    // ── Global Settings ───────────────────────────────────────────────
    'usage_poll_interval_seconds': 30,
    'fallback_engine': 'google',

    // ── Model Kill Switches + Display Names ───────────────────────────
    'model_overrides': {
      'online': {'enabled': true, 'display_name': 'Google Speech'},
      'google': {'enabled': true, 'display_name': 'Google Translate'},
      'mymemory': {'enabled': true, 'display_name': 'MyMemory'},
      'google_api': {'enabled': true, 'display_name': 'Google Cloud'},
      'riva': {'enabled': true, 'display_name': 'NVIDIA Riva'},
      'llama': {'enabled': true, 'display_name': 'Llama 3.1'},
      'whisper-tiny': {'enabled': true, 'display_name': 'Whisper Tiny'},
      'whisper-base': {'enabled': true, 'display_name': 'Whisper Base'},
      'whisper-small': {'enabled': true, 'display_name': 'Whisper Small'},
      'whisper-medium': {'enabled': true, 'display_name': 'Whisper Medium'},
    },

    // ── In-App Announcements ──────────────────────────────────────────
    'announcements': {
      'active': false,
      'message': '',
      'type': 'info',
      'dismiss_key': '',
      'target_tiers': ['free', 'trial', 'pro', 'enterprise'],
    },

    // ── Upgrade Prompts ───────────────────────────────────────────────
    'upgrade_prompts': {
      'show_at_usage_percent': 80,
      'free_trial_days': 7,
      'promo_code_enabled': false,
      'promo_message': '',
      'feature_locked': {
        'title': 'Upgrade Your Plan',
        'message':
            'Get more daily tokens and unlock exclusive features like premium translation engines.',
        'highlights': ['Priority Support'],
      },
    },

    // ── App Version Control ───────────────────────────────────────────
    'app_version': {
      'min_supported': '1.0.0',
      'latest': '1.0.0',
      'update_url': '',
      'force_update_message':
          'A new version of Omni Bridge is available. Please update to continue.',
    },
  };

  Future<void> _updatePollingRate() async {
    final val = int.tryParse(_pollController.text);
    if (val == null || val < 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid polling rate (must be > 0)')),
        );
      }
      return;
    }

    setState(() => _updatingPoll = true);
    try {
      await AuthRemoteDataSource.instance.firestore
          .collection('system')
          .doc('monetization')
          .set(
        {'usage_poll_interval_seconds': val},
        SetOptions(merge: true),
      );
      if (mounted) {
        setState(() => _updatingPoll = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Polling rate updated to $val seconds.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _updatingPoll = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    }
  }

  Future<void> _seedMonetization() async {
    setState(() {
      _seeding = true;
      _lastResult = null;
    });
    try {
      await AuthRemoteDataSource.instance.firestore
          .collection('system')
          .doc('monetization')
          .set({..._seedData, 'last_seeded_at': FieldValue.serverTimestamp()});

      if (mounted) {
        setState(() {
          _seeding = false;
          _lastResult = 'success';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Monetization config seeded successfully.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _seeding = false;
          _lastResult = 'error';
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Seed failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.settings_suggest_rounded,
                  size: 16,
                  color: Colors.orangeAccent,
                ),
                SizedBox(width: 8),
                Text(
                  'SYSTEM CONFIG',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.orangeAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Seed or reset the monetization document with default tier configs, '
              'model overrides, announcements, and version control.',
              style: TextStyle(fontSize: 11, color: Colors.white38),
            ),
            const SizedBox(height: 16),
            const Text(
              'RTDB POLLING RATE (SECONDS)',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _pollController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 12),
                OmniTintedButton(
                  onPressed: _updatingPoll ? null : _updatePollingRate,
                  isLoading: _updatingPoll,
                  icon: Icons.sync_rounded,
                  label: 'Update Rate',
                  color: Colors.tealAccent,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'FULL SEED (CAUTION)',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OmniTintedButton(
                  onPressed: _seeding ? null : _seedMonetization,
                  isLoading: _seeding,
                  icon: _lastResult == 'success'
                      ? Icons.check_circle_outline
                      : Icons.cloud_upload_outlined,
                  label: _seeding ? 'Seeding...' : 'Seed Monetization Config',
                  color: Colors.orangeAccent,
                ),
                if (_lastResult == 'success') ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check, size: 14, color: Colors.greenAccent),
                ],
                if (_lastResult == 'error') ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.error_outline,
                    size: 14,
                    color: Colors.redAccent,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Admin Identity Section ──────────────────────────────────────────────────
// Manages the system/admins Firestore document.
// This is the source of truth for admin access — the admin check in AdminPanel
// reads the same document to decide whether to show this panel at all.

class _AdminIdentitySection extends StatefulWidget {
  const _AdminIdentitySection();

  @override
  State<_AdminIdentitySection> createState() => _AdminIdentitySectionState();
}

class _AdminIdentitySectionState extends State<_AdminIdentitySection> {
  List<String> _adminEmails = [];
  bool _loading = true;
  String? _error;
  final _addController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadAdminEmails();
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminEmails() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final doc = await AuthRemoteDataSource.instance.firestore
          .collection('system')
          .doc('admins')
          .get();
      final emails = List<String>.from(doc.data()?['emails'] ?? []);
      if (mounted) {
        setState(() {
          _adminEmails = emails;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveEmails(List<String> emails) async {
    setState(() => _saving = true);
    try {
      await AuthRemoteDataSource.instance.firestore
          .collection('system')
          .doc('admins')
          .set({'emails': emails}, SetOptions(merge: true));
      if (mounted) {
        setState(() {
          _adminEmails = emails;
          _saving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

  void _addEmail() {
    final email = _addController.text.trim();
    if (email.isEmpty || _adminEmails.contains(email)) return;
    _addController.clear();
    _saveEmails([..._adminEmails, email]);
  }

  void _removeEmail(String email) {
    final updated = _adminEmails.where((e) => e != email).toList();
    _saveEmails(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.shield_rounded,
                  size: 16,
                  color: Colors.amberAccent,
                ),
                const SizedBox(width: 8),
                const Text(
                  'ADMIN IDENTITY',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.amberAccent,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.refresh,
                    size: 16,
                    color: Colors.white38,
                  ),
                  tooltip: 'Refresh',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _loading ? null : _loadAdminEmails,
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Emails in this list are granted admin access.',
              style: TextStyle(fontSize: 11, color: Colors.white38),
            ),
            const SizedBox(height: 12),

            // Email list / loading / error
            if (_loading)
              const Center(child: CircularProgressIndicator(strokeWidth: 2))
            else if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 11),
              )
            else if (_adminEmails.isEmpty)
              const Text(
                'No admin emails configured.',
                style: TextStyle(fontSize: 12, color: Colors.white54),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _adminEmails.map((email) {
                  return Chip(
                    label: Text(email, style: const TextStyle(fontSize: 11)),
                    backgroundColor: Colors.amberAccent.withValues(alpha: 0.1),
                    side: BorderSide(
                      color: Colors.amberAccent.withValues(alpha: 0.3),
                    ),
                    deleteIconColor: Colors.redAccent,
                    onDeleted: _saving ? null : () => _removeEmail(email),
                  );
                }).toList(),
              ),

            const SizedBox(height: 12),

            // Add email input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addController,
                    decoration: const InputDecoration(
                      hintText: 'Add admin email...',
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                    onSubmitted: (_) => _addEmail(),
                  ),
                ),
                const SizedBox(width: 8),
                _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Colors.amberAccent,
                        ),
                        tooltip: 'Add admin',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: _addEmail,
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


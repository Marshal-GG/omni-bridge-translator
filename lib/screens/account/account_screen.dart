import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import '../../core/services/auth_service.dart';
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

  @override
  void initState() {
    super.initState();
    setToAccountPosition();
    final user = AuthService.instance.currentUser.value;
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

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser.value;
    final isAnon = user?.isAnonymous ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WindowBorder(
        color: Colors.white12,
        width: 1,
        child: Container(
          color: const Color(0xFF121212),
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
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 400,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 24,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Avatar
                                buildAccountAvatar(user, isAnon),
                                const SizedBox(height: 36),

                                if (!isAnon) ...[
                                  // ── Display Name Editor ─────────────────────
                                  buildAccountNameEditor(
                                    controller: _nameController,
                                    isSaving: _isSaving,
                                    message: _message,
                                    messageIsError: _messageIsError,
                                    onSave: _updateName,
                                  ),
                                  const SizedBox(height: 24),

                                  // ── Email (read-only) ──────────────────────
                                  buildAccountEmailInfo(user),
                                  const SizedBox(height: 32),
                                ],

                                if (isAnon) const SizedBox(height: 16),

                                // ── Sign Out──────────────────────────────────
                                AccountButton(
                                  icon: Icons.logout,
                                  label: 'Sign Out',
                                  onPressed: _signOut,
                                  isDanger: true,
                                ),
                              ],
                            ),
                          ),
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

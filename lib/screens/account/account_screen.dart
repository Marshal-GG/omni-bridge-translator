import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import '../../core/services/auth_service.dart';
import '../../core/window_manager.dart';

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
      await AuthService.instance.currentUser.value?.updateDisplayName(newName);
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
      await AuthService.instance.signOut();
      await setToLoginPosition();
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
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
              SizedBox(
                height: 32,
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.manage_accounts_rounded,
                      size: 14,
                      color: Colors.white38,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Account',
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
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white10),

              // ── Content ───────────────────────────────────────────────────
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: SizedBox(
                      width: 400,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 24,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Avatar
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: Colors.tealAccent.withValues(
                                alpha: 0.12,
                              ),
                              backgroundImage:
                                  (user?.photoURL?.startsWith('http') == true)
                                  ? NetworkImage(user!.photoURL!)
                                  : null,
                              child:
                                  (user?.photoURL?.startsWith('http') != true)
                                  ? Icon(
                                      isAnon
                                          ? Icons.person_outline
                                          : Icons.person,
                                      color: Colors.tealAccent,
                                      size: 36,
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              isAnon
                                  ? 'Anonymous User'
                                  : (user?.displayName ?? 'No Name'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (!isAnon)
                              Text(
                                user?.email ?? '',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.tealAccent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.tealAccent.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Text(
                                isAnon ? 'Guest Mode' : 'Google Account',
                                style: const TextStyle(
                                  color: Colors.tealAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                            const SizedBox(height: 36),

                            if (!isAnon) ...[
                              // ── Display Name Editor ─────────────────────
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Display Name',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _nameController,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.white.withValues(
                                          alpha: 0.05,
                                        ),
                                        hintText: 'Your display name',
                                        hintStyle: const TextStyle(
                                          color: Colors.white30,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 12,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Colors.white12,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Colors.white12,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Colors.tealAccent,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    height: 46,
                                    child: ElevatedButton(
                                      onPressed: _isSaving ? null : _updateName,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.tealAccent,
                                        foregroundColor: Colors.black,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                      ),
                                      child: _isSaving
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.black,
                                              ),
                                            )
                                          : const Text(
                                              'Save',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),

                              if (_message != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  _message!,
                                  style: TextStyle(
                                    color: _messageIsError
                                        ? Colors.redAccent
                                        : Colors.tealAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              ],

                              const SizedBox(height: 24),

                              // ── Email (read-only) ──────────────────────
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Email',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.email_outlined,
                                      size: 15,
                                      color: Colors.white38,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      user?.email ?? '—',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (user?.emailVerified == true)
                                      const Icon(
                                        Icons.verified,
                                        size: 14,
                                        color: Colors.tealAccent,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),
                            ],

                            if (isAnon) const SizedBox(height: 16),

                            // ── Sign Out──────────────────────────────────
                            _AccountButton(
                              icon: Icons.logout,
                              label: 'Sign Out',
                              onPressed: _signOut,
                              isDanger: true,
                            ),

                            const SizedBox(height: 12),
                            // ── Back ────────────────────────────────────
                            _AccountButton(
                              icon: Icons.arrow_back_rounded,
                              label: 'Back to Translator',
                              onPressed: () async {
                                await setToTranslationPosition();
                                if (mounted) Navigator.pop(context);
                              },
                              isDanger: false,
                            ),
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

// ── Account Button (hover-animated, mirrors _LoginButton) ──────────────────────

class _AccountButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isDanger;

  const _AccountButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.isDanger,
  });

  @override
  State<_AccountButton> createState() => _AccountButtonState();
}

class _AccountButtonState extends State<_AccountButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final danger = widget.isDanger;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 180),
        child: SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: widget.onPressed,
            icon: Icon(
              widget.icon,
              size: 17,
              color: danger
                  ? Colors.redAccent
                  : (_isHovered ? Colors.black87 : Colors.white70),
            ),
            label: Text(
              widget.label,
              style: TextStyle(
                color: danger
                    ? Colors.redAccent
                    : (_isHovered ? Colors.black87 : Colors.white70),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: danger
                  ? (_isHovered
                        ? Colors.redAccent.withValues(alpha: 0.15)
                        : Colors.transparent)
                  : (_isHovered ? Colors.tealAccent : Colors.white10),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: danger
                      ? Colors.redAccent.withValues(alpha: 0.5)
                      : Colors.white12,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

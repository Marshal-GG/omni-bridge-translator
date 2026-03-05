import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import '../core/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String? _error;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final user = await AuthService.instance.signInWithGoogle();
    if (!mounted) return;
    if (user != null) {
      Navigator.pushReplacementNamed(context, '/translation-overlay');
    } else {
      setState(() {
        _isLoading = false;
        _error = 'Sign-in cancelled or failed.';
      });
    }
  }

  Future<void> _bypassForDev() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await AuthService.instance.bypassForDev();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/translation-overlay');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.transparent, // Required for bitsdojo transparency support
      body: WindowBorder(
        color: Colors.white12,
        width: 1,
        child: Container(
          color: const Color(0xFF121212), // Solid background filling the window
          child: Column(
            children: [
              // DRAGGABLE HEADER
              SizedBox(
                height: 32,
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.security_rounded,
                      size: 14,
                      color: Colors.white38,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Authentication Required",
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Expanded(
                      child: MoveWindow(),
                    ), // Entire middle of header is draggable
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

              // CENTERED CONTENT
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: SizedBox(
                      width:
                          400, 
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 20,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Icon/Brand
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.tealAccent.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.translate_rounded,
                                size: 44,
                                color: Colors.tealAccent,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Omni Bridge',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Text(
                          'Live AI Translator',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                            const SizedBox(height: 48),

                            if (_isLoading)
                              const CircularProgressIndicator(
                                color: Colors.tealAccent,
                              )
                            else ...[
                              // Primary Sign In
                              _LoginButton(
                                icon: Icons.login_rounded,
                                label: 'Sign in with Google',
                                onPressed: _signInWithGoogle,
                                isPrimary: true,
                              ),
                              const SizedBox(height: 16),

                              // Secondary Bypass
                              _LoginButton(
                                icon: Icons.developer_mode_rounded,
                                label: 'Continue as Dev',
                                onPressed: _bypassForDev,
                                isPrimary: false,
                              ),
                            ],

                            if (_error != null) ...[
                              const SizedBox(height: 24),
                              Text(
                                _error!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
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

class _LoginButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _LoginButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.isPrimary,
  });

  @override
  State<_LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<_LoginButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isPrimary ? Colors.black87 : Colors.white70;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: widget.onPressed,
            icon: Icon(widget.icon, size: 18, color: textColor),
            label: Text(
              widget.label,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.isPrimary
                  ? (_isHovered ? Colors.white : Colors.tealAccent)
                  : (_isHovered
                        ? Colors.white10
                        : Colors.white.withValues(alpha: 0.05)),
              foregroundColor: textColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: widget.isPrimary
                    ? BorderSide.none
                    : const BorderSide(color: Colors.white10),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

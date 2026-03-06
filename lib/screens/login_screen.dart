import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoginMode = true; // true for login, false for register

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Navigate as soon as Firebase confirms the user — works even when
    // signIn() is still blocking waiting for the OAuth callback URL.
    AuthService.instance.currentUser.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    AuthService.instance.currentUser.removeListener(_onAuthChanged);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    if (AuthService.instance.currentUser.value != null) {
      Navigator.pushReplacementNamed(context, '/translation-overlay');
    }
  }

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

  Future<void> _submitEmailPassword() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      User? user;
      if (_isLoginMode) {
        user = await AuthService.instance.signInWithEmailAndPassword(
          email,
          password,
        );
      } else {
        user = await AuthService.instance.registerWithEmailAndPassword(
          email,
          password,
        );
      }
      if (!mounted) return;
      if (user != null) {
        Navigator.pushReplacementNamed(context, '/translation-overlay');
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Sign-in failed.';
        });
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.message ?? 'Authentication failed.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'An unexpected error occurred: $e';
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
                      width: 400,
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
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 48),

                            if (_isLoading)
                              const CircularProgressIndicator(
                                color: Colors.tealAccent,
                              )
                            else ...[
                              // Email Field
                              TextField(
                                controller: _emailController,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  labelStyle: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 13,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white10,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.email_outlined,
                                    color: Colors.white60,
                                    size: 20,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 0,
                                    horizontal: 16,
                                  ),
                                ),
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 12),
                              // Password Field
                              TextField(
                                controller: _passwordController,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                obscureText: true,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  labelStyle: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 13,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white10,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.lock_outline,
                                    color: Colors.white60,
                                    size: 20,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 0,
                                    horizontal: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Email action button
                              _LoginButton(
                                icon: _isLoginMode
                                    ? Icons.login_rounded
                                    : Icons.person_add_rounded,
                                label: _isLoginMode
                                    ? 'Sign In'
                                    : 'Create Account',
                                onPressed: _submitEmailPassword,
                                isPrimary: true,
                              ),
                              const SizedBox(height: 12),

                              // Toggle Login / Register
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isLoginMode = !_isLoginMode;
                                    _error = null;
                                  });
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.tealAccent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  _isLoginMode
                                      ? "Don't have an account? Sign Up"
                                      : "Already have an account? Sign In",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Divider
                              const Row(
                                children: [
                                  Expanded(
                                    child: Divider(color: Colors.white10),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text(
                                      'OR',
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(color: Colors.white10),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Primary Sign In (Google)
                              _LoginButton(
                                icon: Icons
                                    .g_mobiledata_rounded, // or any other google icon representation
                                label: 'Continue with Google',
                                onPressed: _signInWithGoogle,
                                isPrimary: false,
                              ),
                              const SizedBox(height: 12),

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

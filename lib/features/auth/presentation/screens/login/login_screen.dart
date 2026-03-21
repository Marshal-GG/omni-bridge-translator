import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:omni_bridge/features/auth/data/datasources/auth_remote_datasource.dart';

import 'package:omni_bridge/features/auth/presentation/screens/login/components/login_header.dart';
import 'package:omni_bridge/features/auth/presentation/screens/login/components/login_branding.dart';
import 'package:omni_bridge/features/auth/presentation/screens/login/components/login_inputs.dart';
import 'package:omni_bridge/features/auth/presentation/screens/login/components/login_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoginMode = true;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    AuthRemoteDataSource.instance.currentUser.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    AuthRemoteDataSource.instance.currentUser.removeListener(_onAuthChanged);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    if (AuthRemoteDataSource.instance.currentUser.value != null) {
      Navigator.pushReplacementNamed(context, '/translation-overlay');
      Navigator.pushNamed(context, '/settings-overlay');
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final user = await AuthRemoteDataSource.instance.signInWithGoogle();
    if (!mounted) return;
    if (user != null) {
      Navigator.pushReplacementNamed(context, '/translation-overlay');
      Navigator.pushNamed(context, '/settings-overlay');
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
      if (_isLoginMode) {
        await AuthRemoteDataSource.instance.signInWithEmailAndPassword(email, password);
      } else {
        await AuthRemoteDataSource.instance.registerWithEmailAndPassword(
          email,
          password,
        );
      }
      // _onAuthChanged listener handles navigation on success
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

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(
        () => _error = 'Enter your email above, then tap Forgot Password.',
      );
      return;
    }
    try {
      await AuthRemoteDataSource.instance.sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset email sent to $email'),
          backgroundColor: Colors.teal,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message ?? 'Failed to send reset email.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WindowBorder(
        color: Colors.white12,
        width: 1,
        child: Container(
          color: const Color(0xFF121212),
          child: Column(
            children: [
              buildLoginHeader(),
              const Divider(height: 1, color: Colors.white10),
              Expanded(
                child: SingleChildScrollView(
                  child: Center(
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
                            buildLoginBranding(),
                            const SizedBox(height: 48),

                            if (_isLoading)
                              const CircularProgressIndicator(
                                color: Colors.tealAccent,
                              )
                            else ...[
                              buildLoginInputs(
                                emailController: _emailController,
                                passwordController: _passwordController,
                              ),
                              const SizedBox(height: 4),

                              // Forgot Password — only visible in login mode
                              if (_isLoginMode)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _forgotPassword,
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.tealAccent,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Forgot password?',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 16),

                              LoginButton(
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

                              TextButton(
                                onPressed: () => setState(() {
                                  _isLoginMode = !_isLoginMode;
                                  _error = null;
                                }),
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

                              // Google button with proper logo
                              _GoogleSignInButton(onPressed: _signInWithGoogle),
                              const SizedBox(height: 12),

                              // View Tutorial button
                              TextButton.icon(
                                onPressed: () =>
                                    Navigator.pushNamed(context, '/onboarding'),
                                icon: const Icon(
                                  Icons.help_outline_rounded,
                                  size: 16,
                                ),
                                label: const Text('View Tutorial'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white54,
                                  textStyle: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
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

/// Google Sign-In button with the proper four-color Google G logo.
class _GoogleSignInButton extends StatefulWidget {
  const _GoogleSignInButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<_GoogleSignInButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white10.withValues(alpha: _isHovered ? 0.15 : 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/google-logo.png', width: 20, height: 20),
              const SizedBox(width: 10),
              const Text(
                'Continue with Google',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
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




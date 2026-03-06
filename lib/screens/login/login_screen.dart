import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/auth_service.dart';

import 'components/login_header.dart';
import 'components/login_branding.dart';
import 'components/login_inputs.dart';
import 'components/login_button.dart';

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
      if (_isLoginMode) {
        await AuthService.instance.signInWithEmailAndPassword(email, password);
      } else {
        await AuthService.instance.registerWithEmailAndPassword(
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
                              const SizedBox(height: 24),

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

                              LoginButton(
                                icon: Icons.g_mobiledata_rounded,
                                label: 'Continue with Google',
                                onPressed: _signInWithGoogle,
                                isPrimary: false,
                              ),
                              const SizedBox(height: 12),

                              LoginButton(
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

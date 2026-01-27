import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/cloud_sync_service.dart';

/// Authentication screen for Firebase email/password sign-in
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App logo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 100,
                      height: 100,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.security,
                        size: 80,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'OmniOTP',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Secure TOTP Authenticator',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Error message
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Email field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: _isSignUp
                        ? TextInputAction.next
                        : TextInputAction.done,
                    onFieldSubmitted: _isSignUp
                        ? null
                        : (_) => _submitForm(context),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (_isSignUp && value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),

                  // Confirm password field (sign up only)
                  if (_isSignUp) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submitForm(context),
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            );
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () => _submitForm(context),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isSignUp ? 'Create Account' : 'Sign In'),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Toggle sign up / sign in
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _isSignUp = !_isSignUp;
                              _errorMessage = null;
                              _confirmPasswordController.clear();
                            });
                          },
                    child: Text(
                      _isSignUp
                          ? 'Already have an account? Sign In'
                          : "Don't have an account? Sign Up",
                    ),
                  ),

                  // Forgot password (sign in only)
                  if (!_isSignUp)
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => _showForgotPasswordDialog(context),
                      child: const Text('Forgot Password?'),
                    ),

                  const SizedBox(height: 8),

                  // Skip button for local-only mode
                  TextButton(
                    onPressed: _isLoading ? null : () => _skipSignIn(context),
                    child: const Text('Use without account'),
                  ),

                  const SizedBox(height: 32),

                  // Security info
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: const [
                          Row(
                            children: [
                              Icon(Icons.lock_outline, color: Colors.green),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Your secrets are encrypted locally and never sent to our servers',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.sync_disabled, color: Colors.blue),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Sync is optional - your accounts stay encrypted end-to-end',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitForm(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final navigator = Navigator.of(context);
    final authService = context.read<AuthService>();
    final cloudSyncService = context.read<CloudSyncService>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    AuthResult result;
    if (_isSignUp) {
      result = await authService.signUpWithEmail(email, password);
    } else {
      result = await authService.signInWithEmail(email, password);
    }

    if (!mounted) return;

    if (result.success) {
      // Initialize sync encryption with user's credentials
      // This derives the cross-platform encryption key
      try {
        await cloudSyncService.initializeSyncEncryption(email, password);
      } catch (e) {
        // Non-fatal - sync will just not work
        debugPrint('Failed to initialize sync encryption: $e');
      }
      
      setState(() => _isLoading = false);
      navigator.pushReplacementNamed('/home');
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result.errorMessage;
      });
    }
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final resetEmailController = TextEditingController(
      text: _emailController.text,
    );
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final authService = context.read<AuthService>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your email to receive a password reset link.'),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = resetEmailController.text.trim();
              if (email.isEmpty) return;

              final navigator = Navigator.of(dialogContext);
              final result = await authService.sendPasswordResetEmail(email);

              if (!mounted) return;
              navigator.pop();

              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text(
                    result.success
                        ? 'Password reset email sent'
                        : result.errorMessage ?? 'Failed to send email',
                  ),
                ),
              );
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _skipSignIn(BuildContext context) {
    Navigator.pushReplacementNamed(context, '/home');
  }
}

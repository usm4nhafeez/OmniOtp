import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';

/// Authentication screen for Firebase sign-in
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App icon and title
                Icon(
                  Icons.security,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
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
                const SizedBox(height: 48),

                // Error message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (_errorMessage != null) const SizedBox(height: 16),

                // Sign in button
                _isLoading
                    ? const CircularProgressIndicator()
                    : Column(
                      children: [
                        // Google Sign-In button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _signInWithGoogle(context),
                            icon: const Icon(Icons.g_mobiledata, size: 28),
                            label: const Text('Sign in with Google'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Skip button for local-only mode
                        TextButton(
                          onPressed: () => _skipSignIn(context),
                          child: const Text('Use without account'),
                        ),
                      ],
                    ),

                const SizedBox(height: 48),

                // Security info
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: const [
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
                        const SizedBox(height: 12),
                        Row(
                          children: const [
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
    );
  }

  Future<void> _signInWithGoogle(BuildContext context) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = context.read<AuthService>();
    final result = await authService.signInWithGoogle();

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result.success) {
      // Navigate to home
      Navigator.pushReplacementNamed(this.context, '/home');
    } else if (!result.cancelled) {
      setState(() {
        _errorMessage = result.errorMessage;
      });
    }
  }

  void _skipSignIn(BuildContext context) {
    // Navigate to home without signing in
    Navigator.pushReplacementNamed(context, '/home');
  }
}

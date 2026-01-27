import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../../services/cloud_sync_service.dart';
import '../screens/auth_screen.dart';

/// Settings screen with account and security options
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _useBiometric = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _useBiometric = prefs.getBool('use_biometric') ?? false;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final biometricService = context.read<BiometricService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Account section
                if (authService.isSignedIn) ...[
                  const _SectionHeader(title: 'Account'),
                  ListTile(
                    leading: const Icon(Icons.account_circle),
                    title: const Text('Email'),
                    subtitle: Text(authService.currentUser?.email ?? 'Unknown'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.sync),
                    title: const Text('Sync Status'),
                    subtitle: const Text('Cloud sync enabled'),
                    trailing: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Sign Out'),
                    onTap: () => _confirmSignOut(context, authService),
                  ),
                  const Divider(),
                ],

                // Security section
                const _SectionHeader(title: 'Security'),
                FutureBuilder<bool>(
                  future: biometricService.isBiometricAvailable(),
                  builder: (context, snapshot) {
                    final isAvailable = snapshot.data ?? false;
                    return SwitchListTile(
                      secondary: const Icon(Icons.fingerprint),
                      title: const Text('Biometric Lock'),
                      subtitle: Text(
                        isAvailable
                            ? 'Lock app with fingerprint/face'
                            : 'Biometric not available on this device',
                      ),
                      value: _useBiometric && isAvailable,
                      onChanged: isAvailable
                          ? (value) => _toggleBiometric(value, biometricService)
                          : null,
                    );
                  },
                ),
                const Divider(),

                // Data management
                const _SectionHeader(title: 'Data'),
                ListTile(
                  leading: const Icon(Icons.cloud_download),
                  title: const Text('Manual Sync'),
                  subtitle: const Text('Sync with cloud now'),
                  onTap: authService.isSignedIn
                      ? () => _manualSync(context)
                      : null,
                  enabled: authService.isSignedIn,
                ),
                ListTile(
                  leading: const Icon(Icons.backup),
                  title: const Text('Export Accounts'),
                  subtitle: const Text('Coming soon'),
                  enabled: false,
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Delete All Data'),
                  subtitle: const Text('Remove all local accounts'),
                  onTap: () => _confirmDeleteAll(context),
                ),
                const Divider(),

                // App info
                const _SectionHeader(title: 'About'),
                const ListTile(
                  leading: Icon(Icons.info),
                  title: Text('Version'),
                  subtitle: Text('1.0.0'),
                ),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Privacy'),
                  subtitle: const Text('End-to-end encrypted'),
                  trailing: const Icon(Icons.check_circle, color: Colors.green),
                ),
              ],
            ),
    );
  }

  Future<void> _toggleBiometric(
    bool value,
    BiometricService biometricService,
  ) async {
    if (value) {
      // Test biometric before enabling
      final success = await biometricService.authenticate(
        reason: 'Enable biometric lock',
      );
      if (!success) return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_biometric', value);
    setState(() => _useBiometric = value);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? 'Biometric lock enabled' : 'Biometric lock disabled',
          ),
        ),
      );
    }
  }

  Future<void> _manualSync(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final provider = context.read<TotpProvider>();
      await provider.syncWithCloud();
      messenger.showSnackBar(
        const SnackBar(content: Text('Sync completed successfully')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Sync failed: $e')));
    }
  }

  Future<void> _confirmSignOut(
    BuildContext context,
    AuthService authService,
  ) async {
    final navigator = Navigator.of(context);
    final cloudSyncService = context.read<CloudSyncService>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out? Your local data will remain on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Clear sync encryption key before signing out
      cloudSyncService.clearSyncEncryption();

      await authService.signOut();
      if (mounted) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _confirmDeleteAll(BuildContext context) async {
    final provider = context.read<TotpProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete All Data'),
        content: const Text(
          'This will permanently delete all your TOTP accounts from this device. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final accounts = List.from(provider.accounts);
      for (final account in accounts) {
        await provider.deleteAccount(account.id);
      }

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('All accounts deleted')),
        );
        navigator.pop();
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

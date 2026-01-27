import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../../main.dart';
import '../../services/auth_service.dart';
import '../../services/totp_service.dart';
import '../../models/totp_account.dart';
import '../components/account_card.dart';

/// Main home screen showing TOTP accounts list
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final provider = context.read<TotpProvider>();
    await provider.loadAccounts();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TotpProvider>();
    final authService = context.read<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('OmniOTP'),
        actions: [
          // Sync button
          if (authService.isSignedIn)
            IconButton(
              icon: const Icon(Icons.sync),
              onPressed: () => _syncWithCloud(provider),
            ),
          // Settings
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.accounts.isEmpty
          ? _buildEmptyState()
          : _buildAccountList(provider),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addAccount(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/logo.png',
              width: 80,
              height: 80,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.security_outlined,
                size: 80,
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No accounts yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first TOTP account',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountList(TotpProvider provider) {
    return Column(
      children: [
        // Timer indicator
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.timer,
                size: 16,
                color: _getTimerColor(provider.remainingSeconds),
              ),
              const SizedBox(width: 8),
              Text(
                '${provider.remainingSeconds}s',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _getTimerColor(provider.remainingSeconds),
                ),
              ),
            ],
          ),
        ),
        // Account list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: provider.accounts.length,
            itemBuilder: (context, index) {
              final account = provider.accounts[index];
              return AccountCard(
                account: account,
                otp: provider.getOtpForAccount(account),
                onTap: () => _copyOtp(context, account),
                onDelete: () => _deleteAccount(context, account),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getTimerColor(int seconds) {
    if (seconds <= 5) return Colors.red;
    if (seconds <= 10) return Colors.orange;
    return Theme.of(context).colorScheme.primary;
  }

  void _copyOtp(BuildContext context, TotpAccount account) {
    final otp = TotpService.generateCode(account);
    final messenger = ScaffoldMessenger.of(context);
    Clipboard.setData(ClipboardData(text: otp)).then((_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Copied ${account.issuer} code'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  Future<void> _deleteAccount(BuildContext context, TotpAccount account) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: Text('Remove ${account.issuer} (${account.accountName})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<TotpProvider>().deleteAccount(account.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _addAccount(BuildContext context) {
    Navigator.pushNamed(context, '/add-account');
  }

  Future<void> _syncWithCloud(TotpProvider provider) async {
    try {
      await provider.syncWithCloud();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Synced with cloud')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
      }
    }
  }
}

import 'package:flutter/material.dart';

import '../../models/totp_account.dart';

/// Card displaying a TOTP account with the current code
class AccountCard extends StatelessWidget {
  final TotpAccount account;
  final String otp;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const AccountCard({
    super.key,
    required this.account,
    required this.otp,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Issuer icon/avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getIssuerColor(account.issuer).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    account.issuer.isNotEmpty
                        ? account.issuer[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _getIssuerColor(account.issuer),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Account info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.issuer,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _maskAccount(account.accountName),
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // OTP Code
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatOtp(otp),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to copy',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),

              // Delete button
              PopupMenuButton(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder:
                    (context) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: const [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatOtp(String otp) {
    // Format as "123 456" for readability
    if (otp.length == 6) {
      return '${otp.substring(0, 3)} ${otp.substring(3)}';
    } else if (otp.length == 8) {
      return '${otp.substring(0, 4)} ${otp.substring(4)}';
    }
    return otp;
  }

  String _maskAccount(String account) {
    if (account.contains('@')) {
      // Mask email addresses
      final parts = account.split('@');
      final username = parts[0];
      final domain = parts[1];
      if (username.length > 2) {
        return '${username.substring(0, 2)}***@$domain';
      }
      return '***@$domain';
    }
    return account;
  }

  Color _getIssuerColor(String issuer) {
    // Generate consistent colors for different issuers
    final hash = issuer.hashCode.abs();
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.amber,
      Colors.cyan,
    ];
    return colors[hash % colors.length];
  }
}

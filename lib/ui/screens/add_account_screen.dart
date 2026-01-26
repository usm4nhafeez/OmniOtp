import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../services/qr_parser_service.dart';
import '../../services/totp_service.dart';
import '../../models/totp_account.dart';

/// Screen to add new TOTP accounts via QR scan or manual entry
class AddAccountScreen extends StatefulWidget {
  const AddAccountScreen({super.key});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  bool _isScanning = false;
  String? _errorMessage;

  // Manual entry form controllers
  final _issuerController = TextEditingController();
  final _accountController = TextEditingController();
  final _secretController = TextEditingController();

  @override
  void dispose() {
    _issuerController.dispose();
    _accountController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Account'),
        actions: [
          TextButton(
            onPressed: _isScanning ? _stopScanning : _startScanning,
            child: Text(_isScanning ? 'Cancel' : 'Scan QR'),
          ),
        ],
      ),
      body: _isScanning ? _buildQrScanner() : _buildManualEntry(context),
    );
  }

  Widget _buildQrScanner() {
    return MobileScanner(
      onDetect: (capture) {
        final barcode = capture.barcodes.first;
        if (barcode.rawValue != null) {
          _processQrCode(barcode.rawValue!);
        }
      },
    );
  }

  void _startScanning() {
    setState(() => _isScanning = true);
  }

  void _stopScanning() {
    setState(() => _isScanning = false);
  }

  void _processQrCode(String code) {
    // Stop scanning after first detection
    _stopScanning();

    // Parse the QR code
    final account = QrParserService.parse(code);

    if (account != null) {
      setState(() {
        _errorMessage = null;
      });

      // Populate form fields for review
      _issuerController.text = account.issuer;
      _accountController.text = account.accountName;
      _secretController.text = account.secret;
    } else {
      setState(() {
        _errorMessage = 'Invalid TOTP QR code';
      });
    }
  }

  Widget _buildManualEntry(BuildContext context) {
    final provider = context.read<TotpProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Error message
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.withValues( alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),

          // Instructions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter account details',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scan a QR code from your service or enter the details manually',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues( alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Issuer field
          TextField(
            controller: _issuerController,
            decoration: const InputDecoration(
              labelText: 'Issuer (e.g., Google, GitHub)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.business),
            ),
          ),

          const SizedBox(height: 16),

          // Account name field
          TextField(
            controller: _accountController,
            decoration: const InputDecoration(
              labelText: 'Account (e.g., user@example.com)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
          ),

          const SizedBox(height: 16),

          // Secret field
          TextField(
            controller: _secretController,
            decoration: const InputDecoration(
              labelText: 'Secret Key (Base32)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.vpn_key),
              helperText: 'Enter the Base32 secret key',
            ),
          ),

          const SizedBox(height: 24),

          // Add button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _addAccount(provider),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Add Account'),
            ),
          ),
        ],
      ),
    );
  }

  bool _validateFields() {
    if (_issuerController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Issuer is required');
      return false;
    }
    if (_accountController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Account name is required');
      return false;
    }
    if (_secretController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Secret is required');
      return false;
    }

    final secret = Base32.normalize(_secretController.text.trim());
    if (!TotpService.isValidSecret(secret)) {
      setState(() => _errorMessage = 'Invalid Base32 secret');
      return false;
    }

    return true;
  }

  void _addAccount(TotpProvider provider) {
    if (!_validateFields()) return;

    final account = TotpAccount(
      issuer: _issuerController.text.trim(),
      accountName: _accountController.text.trim(),
      secret: Base32.normalize(_secretController.text.trim()),
    );

    provider
        .addAccount(account)
        .then((_) {
          if (mounted) {
            Navigator.pop(context);
          }
        })
        .catchError((error) {
          setState(() => _errorMessage = 'Failed to add account: $error');
        });
  }
}

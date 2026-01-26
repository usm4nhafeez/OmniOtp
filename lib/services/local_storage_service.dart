import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'encryption_service.dart';
import '../models/totp_account.dart';

/// Local storage service for encrypted TOTP accounts
/// Uses platform-specific secure storage
class LocalStorageService {
  static const String _encryptedDataKey = 'omniotp_vault_data';

  final EncryptionService _encryption;
  final FlutterSecureStorage _storage;

  LocalStorageService({
    required EncryptionService encryption,
    FlutterSecureStorage? storage,
  }) : _encryption = encryption,
       _storage = storage ?? const FlutterSecureStorage();

  /// Load all accounts from local storage
  /// Returns empty list if no data exists
  Future<List<TotpAccount>> loadAccounts() async {
    try {
      final encryptedData = await _storage.read(key: _encryptedDataKey);
      if (encryptedData == null || encryptedData.isEmpty) {
        return [];
      }

      final decryptedMaps = await _encryption.decryptAccounts(encryptedData);
      return decryptedMaps.map((m) => TotpAccount.fromVaultMap(m)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Save all accounts to local storage
  /// Encrypts data before storing
  Future<void> saveAccounts(List<TotpAccount> accounts) async {
    final accountMaps = accounts.map((a) => a.toVaultMap()).toList();
    final encryptedData = await _encryption.encryptAccounts(accountMaps);
    await _storage.write(key: _encryptedDataKey, value: encryptedData);
  }

  /// Add a single account
  Future<void> addAccount(TotpAccount account) async {
    final accounts = await loadAccounts();
    accounts.add(account);
    await saveAccounts(accounts);
  }

  /// Update an existing account
  Future<void> updateAccount(TotpAccount account) async {
    final accounts = await loadAccounts();
    final index = accounts.indexWhere((a) => a.id == account.id);
    if (index != -1) {
      accounts[index] = account;
      await saveAccounts(accounts);
    }
  }

  /// Delete an account by ID
  Future<void> deleteAccount(String accountId) async {
    final accounts = await loadAccounts();
    accounts.removeWhere((a) => a.id == accountId);
    await saveAccounts(accounts);
  }

  /// Clear all local data
  Future<void> clearAll() async {
    await _storage.delete(key: _encryptedDataKey);
  }

  /// Check if data exists
  Future<bool> hasData() async {
    return await _storage.containsKey(key: _encryptedDataKey);
  }
}

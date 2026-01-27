import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/totp_account.dart';
import 'encryption_service.dart';
import 'local_storage_service.dart';
import 'sync_encryption_service.dart';

/// Cloud sync service using Firebase Firestore
/// Uses password-derived encryption for cross-platform compatibility
class CloudSyncService {
  static const String _vaultCollection = 'vaults';
  static const String _vaultField = 'encryptedData';
  static const String _userIdField = 'userId';
  static const String _updatedAtField = 'updatedAt';
  static const String _versionField = 'version';

  final FirebaseFirestore _firestore;
  final EncryptionService _encryption; // Local encryption (device-specific)
  final LocalStorageService _localStorage;
  SyncEncryptionService? _syncEncryption; // Cross-platform encryption

  CloudSyncService({
    FirebaseFirestore? firestore,
    required EncryptionService encryption,
    required LocalStorageService localStorage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _encryption = encryption,
       _localStorage = localStorage;

  /// Initialize sync encryption with user's credentials
  /// Must be called after successful login
  Future<void> initializeSyncEncryption(String email, String password) async {
    _syncEncryption = SyncEncryptionService();
    await _syncEncryption!.deriveKey(email, password);
  }

  /// Clear sync encryption key (on logout)
  void clearSyncEncryption() {
    _syncEncryption?.clearKey();
    _syncEncryption = null;
  }

  /// Check if sync encryption is ready
  bool get isSyncReady => _syncEncryption?.isInitialized ?? false;

  /// Get the user's vault document reference
  DocumentReference _getUserVault(String userId) {
    return _firestore.collection(_vaultCollection).doc(userId);
  }

  /// Sync local data to cloud using password-derived encryption
  Future<void> syncToCloud(String userId, List<TotpAccount> accounts) async {
    if (_syncEncryption == null || !_syncEncryption!.isInitialized) {
      throw SyncException('Sync encryption not initialized. Please sign in again.');
    }

    try {
      final accountMaps = accounts.map((a) => a.toVaultMap()).toList();
      final encryptedData = await _syncEncryption!.encryptAccounts(accountMaps);

      await _getUserVault(userId).set({
        _vaultField: encryptedData,
        _userIdField: userId,
        _versionField: 2, // Version 2 = password-derived encryption
        _updatedAtField: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw SyncException('Failed to sync to cloud: $e');
    }
  }

  /// Sync cloud data to local using password-derived encryption
  Future<List<TotpAccount>> syncFromCloud(String userId) async {
    if (_syncEncryption == null || !_syncEncryption!.isInitialized) {
      throw SyncException('Sync encryption not initialized. Please sign in again.');
    }

    try {
      final doc = await _getUserVault(userId).get();
      final data = doc.data() as Map<String, dynamic>?;
      if (!doc.exists || data == null || data[_vaultField] == null) {
        return [];
      }

      final encryptedData = data[_vaultField] as String;
      final version = data[_versionField] as int? ?? 1;
      
      if (version < 2) {
        // Old format - can't decrypt without device-specific key
        throw SyncException(
          'Cloud data uses old encryption format. '
          'Please re-upload from the original device or add accounts again.'
        );
      }

      final decryptedMaps = await _syncEncryption!.decryptAccounts(encryptedData);
      return decryptedMaps.map((m) => TotpAccount.fromVaultMap(m)).toList();
    } catch (e) {
      if (e is SyncException) rethrow;
      throw SyncException('Failed to sync from cloud: $e');
    }
  }

  /// Perform two-way sync
  /// Merges local and cloud data (cloud wins on conflict)
  Future<SyncResult> performSync(String userId) async {
    try {
      final localAccounts = await _localStorage.loadAccounts();
      final cloudAccounts = await syncFromCloud(userId);

      if (cloudAccounts.isEmpty) {
        // No cloud data, upload local
        if (localAccounts.isNotEmpty) {
          await syncToCloud(userId, localAccounts);
        }
        return SyncResult(
          localCount: localAccounts.length,
          cloudCount: 0,
          syncedCount: localAccounts.length,
          syncType: SyncType.upload,
        );
      }

      // Merge accounts
      final merged = _mergeAccounts(localAccounts, cloudAccounts);

      // Upload merged data to cloud
      await syncToCloud(userId, merged);

      // Update local storage
      await _localStorage.saveAccounts(merged);

      return SyncResult(
        localCount: localAccounts.length,
        cloudCount: cloudAccounts.length,
        syncedCount: merged.length,
        syncType: SyncType.bidirectional,
      );
    } catch (e) {
      throw SyncException('Sync failed: $e');
    }
  }

  /// Merge local and cloud accounts
  /// Cloud data takes precedence for conflicts
  List<TotpAccount> _mergeAccounts(
    List<TotpAccount> local,
    List<TotpAccount> cloud,
  ) {
    final accountMap = <String, TotpAccount>{};

    // Add all cloud accounts (they take precedence)
    for (final account in cloud) {
      accountMap[account.id] = account;
    }

    // Add local-only accounts
    for (final account in local) {
      if (!accountMap.containsKey(account.id)) {
        accountMap[account.id] = account;
      }
    }

    return accountMap.values.toList()
      ..sort((a, b) => a.issuer.compareTo(b.issuer));
  }

  /// Check if sync is available
  Future<bool> isAvailable() async {
    try {
      // Quick connectivity check
      await _firestore.collection(_vaultCollection).limit(1).get();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete user's cloud vault
  Future<void> deleteCloudVault(String userId) async {
    await _getUserVault(userId).delete();
  }

  /// Subscribe to real-time sync updates
  StreamSubscription<DocumentSnapshot> subscribeToChanges(
    String userId,
    void Function(List<TotpAccount>) onUpdate,
  ) {
    return _getUserVault(userId).snapshots().listen((snapshot) async {
      final data = snapshot.data() as Map<String, dynamic>?;
      if (snapshot.exists && data != null && data[_vaultField] != null) {
        final encryptedData = data[_vaultField] as String;
        final decryptedMaps = await _encryption.decryptAccounts(encryptedData);
        final accounts =
            decryptedMaps.map((m) => TotpAccount.fromVaultMap(m)).toList();
        onUpdate(accounts);
      }
    });
  }
}

/// Result of a sync operation
class SyncResult {
  final int localCount;
  final int cloudCount;
  final int syncedCount;
  final SyncType syncType;

  SyncResult({
    required this.localCount,
    required this.cloudCount,
    required this.syncedCount,
    required this.syncType,
  });
}

enum SyncType { upload, download, bidirectional, none }

class SyncException implements Exception {
  final String message;
  SyncException(this.message);

  @override
  String toString() => message;
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/export.dart';

/// Cross-platform encryption service using password-derived keys
/// Uses PBKDF2 for key derivation + AES-256-GCM for encryption
/// Same parameters used in Chrome extension for compatibility
class SyncEncryptionService {
  // Fixed salt for PBKDF2 - must match extension
  // In production, consider per-user salt stored in Firestore
  static const String _fixedSalt = 'OmniOTP_Sync_Salt_v1';
  static const int _iterations = 100000;
  static const int _keyLength = 32; // 256 bits
  static const int _ivLength = 12; // 96 bits for GCM

  Uint8List? _derivedKey;
  String? _userEmail;

  /// Derive encryption key from user's email and password
  /// Uses PBKDF2-SHA256 with fixed parameters for cross-platform compatibility
  Future<void> deriveKey(String email, String password) async {
    _userEmail = email;
    
    // Create salt from fixed salt + email for user-specific derivation
    final saltString = '$_fixedSalt:$email';
    final salt = utf8.encode(saltString);
    
    // PBKDF2 key derivation
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(Pbkdf2Parameters(
      Uint8List.fromList(salt),
      _iterations,
      _keyLength,
    ));
    
    final passwordBytes = Uint8List.fromList(utf8.encode(password));
    _derivedKey = pbkdf2.process(passwordBytes);
  }

  /// Check if key is derived
  bool get isInitialized => _derivedKey != null;

  /// Get the derived key (for debugging only - don't expose in production)
  String? get keyHash => _derivedKey != null 
      ? sha256.convert(_derivedKey!).toString().substring(0, 16) 
      : null;

  /// Clear the derived key (on logout)
  void clearKey() {
    _derivedKey = null;
    _userEmail = null;
  }

  /// Encrypt data using AES-256-GCM
  /// Returns base64 encoded: IV (12 bytes) + ciphertext + auth tag
  Future<String> encrypt(String plainText) async {
    if (_derivedKey == null) {
      throw StateError('Encryption key not derived. Call deriveKey() first.');
    }

    final key = Key(_derivedKey!);
    final iv = IV.fromSecureRandom(_ivLength);
    
    final encrypter = Encrypter(AES(key, mode: AESMode.gcm, padding: null));
    final encrypted = encrypter.encrypt(plainText, iv: iv);

    // Combine IV + ciphertext for storage
    final combined = Uint8List.fromList(iv.bytes + encrypted.bytes);
    return base64Encode(combined);
  }

  /// Decrypt data
  /// Expects base64 encoded: IV (12 bytes) + ciphertext + auth tag
  Future<String> decrypt(String encryptedBase64) async {
    if (_derivedKey == null) {
      throw StateError('Encryption key not derived. Call deriveKey() first.');
    }

    final combined = base64Decode(encryptedBase64);
    
    // Split IV and ciphertext
    final iv = IV(Uint8List.fromList(combined.sublist(0, _ivLength)));
    final ciphertext = Uint8List.fromList(combined.sublist(_ivLength));

    final key = Key(_derivedKey!);
    final encrypter = Encrypter(AES(key, mode: AESMode.gcm, padding: null));
    
    return encrypter.decrypt(Encrypted(ciphertext), iv: iv);
  }

  /// Encrypt accounts list for cloud sync
  Future<String> encryptAccounts(List<Map<String, dynamic>> accounts) async {
    final data = {
      'version': 2, // Version 2 = password-derived encryption
      'accounts': accounts,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'email': _userEmail,
    };
    return encrypt(jsonEncode(data));
  }

  /// Decrypt accounts list from cloud
  Future<List<Map<String, dynamic>>> decryptAccounts(String encryptedBase64) async {
    final jsonStr = await decrypt(encryptedBase64);
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    
    // Verify version
    final version = data['version'] as int?;
    if (version != 2) {
      throw FormatException('Incompatible vault version: $version. Expected version 2.');
    }
    
    final accounts = data['accounts'] as List<dynamic>;
    return accounts.map((a) => Map<String, dynamic>.from(a)).toList();
  }
}

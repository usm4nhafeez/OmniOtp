import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart';

/// AES-256-GCM encryption service for TOTP secrets
/// Derives encryption key from local master key stored in secure storage
class EncryptionService {
  static const String _keyStorageKey = 'omniotp_master_key';
  static const String _ivStorageKey = 'omniotp_iv';
  static const int _keyLength = 32; // 256 bits
  static const int _ivLength = 12; // 96 bits for GCM

  final FlutterSecureStorage _secureStorage;
  late final Encrypter _encrypter;

  EncryptionService({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Initialize encryption - generates master key if not exists
  Future<void> initialize() async {
    final keyExists = await _secureStorage.containsKey(key: _keyStorageKey);

    if (!keyExists) {
      // Generate cryptographically secure random master key
      final masterKey = _generateSecureRandom(_keyLength);
      await _secureStorage.write(
        key: _keyStorageKey,
        value: base64Encode(masterKey),
      );

      // Generate and store IV
      final iv = _generateSecureRandom(_ivLength);
      await _secureStorage.write(key: _ivStorageKey, value: base64Encode(iv));
    }

    // Load key and create encrypter
    final keyBase64 = await _secureStorage.read(key: _keyStorageKey);
    final keyBytes = base64Decode(keyBase64!);

    _encrypter = Encrypter(
      AES(Key(keyBytes), mode: AESMode.gcm, padding: null),
    );
  }

  /// Check if encryption is initialized
  Future<bool> isInitialized() async {
    return await _secureStorage.containsKey(key: _keyStorageKey);
  }

  /// Encrypt a string value using AES-256-GCM
  /// Returns base64 encoded encrypted data
  Future<String> encrypt(String plainText) async {
    final iv = IV.fromSecureRandom(_ivLength);
    final encrypted = _encrypter.encrypt(plainText, iv: iv);

    // Combine IV and ciphertext for storage
    final combined = Uint8List.fromList(iv.bytes + encrypted.bytes);
    return base64Encode(combined);
  }

  /// Decrypt a string value
  /// Expects base64 encoded data with IV prepended
  Future<String> decrypt(String encryptedBase64) async {
    final combined = base64Decode(encryptedBase64);

    // Split IV and ciphertext
    final iv = IV(combined.sublist(0, _ivLength));
    final ciphertext = combined.sublist(_ivLength);

    final decrypted = _encrypter.decrypt(Encrypted(ciphertext), iv: iv);
    return decrypted;
  }

  /// Encrypt JSON data
  Future<String> encryptJson(Map<String, dynamic> data) async {
    return encrypt(jsonEncode(data));
  }

  /// Decrypt JSON data
  Future<Map<String, dynamic>> decryptJson(String encryptedBase64) async {
    final jsonStr = await decrypt(encryptedBase64);
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }

  /// Encrypt list of accounts (each as a map)
  Future<String> encryptAccounts(List<Map<String, dynamic>> accounts) async {
    final data = {
      'version': 1,
      'accounts': accounts,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    return encryptJson(data);
  }

  /// Decrypt list of accounts
  Future<List<Map<String, dynamic>>> decryptAccounts(
    String encryptedBase64,
  ) async {
    final data = await decryptJson(encryptedBase64);
    final accounts = data['accounts'] as List<dynamic>;
    return accounts.map((a) => Map<String, dynamic>.from(a)).toList();
  }

  /// Wipe all encryption keys (use with caution - data will be lost)
  Future<void> wipeKeys() async {
    await _secureStorage.delete(key: _keyStorageKey);
    await _secureStorage.delete(key: _ivStorageKey);
  }

  /// Generate cryptographically secure random bytes
  Uint8List _generateSecureRandom(int length) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }
}

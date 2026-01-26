import 'package:uuid/uuid.dart';

/// Represents a TOTP account configuration
class TotpAccount {
  final String id;
  final String issuer;
  final String accountName;
  final String secret; // Base32 encoded secret
  final TotpAlgorithm algorithm;
  final int digits;
  final int period;

  TotpAccount({
    String? id,
    required this.issuer,
    required this.accountName,
    required this.secret,
    this.algorithm = TotpAlgorithm.sha1,
    this.digits = 6,
    this.period = 30,
  }) : id = id ?? const Uuid().v4();

  /// Create from decrypted data
  factory TotpAccount.fromDecrypted({
    required String id,
    required String issuer,
    required String accountName,
    required String secret,
    String algorithm = 'SHA1',
    int digits = 6,
    int period = 30,
  }) {
    return TotpAccount(
      id: id,
      issuer: issuer,
      accountName: accountName,
      secret: secret,
      algorithm: TotpAlgorithm.fromString(algorithm),
      digits: digits,
      period: period,
    );
  }

  /// Create from encrypted vault data
  factory TotpAccount.fromVaultMap(Map<String, dynamic> map) {
    return TotpAccount(
      id: map['id'] as String,
      issuer: map['issuer'] as String,
      accountName: map['accountName'] as String,
      secret: map['secret'] as String,
      algorithm: TotpAlgorithm.fromString(map['algorithm'] ?? 'SHA1'),
      digits: map['digits'] ?? 6,
      period: map['period'] ?? 30,
    );
  }

  /// Convert to vault storage format (encrypted)
  Map<String, dynamic> toVaultMap() {
    return {
      'id': id,
      'issuer': issuer,
      'accountName': accountName,
      'secret': secret,
      'algorithm': algorithm.toString().split('.').last.toUpperCase(),
      'digits': digits,
      'period': period,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TotpAccount &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

enum TotpAlgorithm {
  sha1,
  sha256,
  sha512,
  md5;

  static TotpAlgorithm fromString(String value) {
    switch (value.toUpperCase()) {
      case 'SHA256':
        return sha256;
      case 'SHA512':
        return sha512;
      case 'MD5':
        return md5;
      default:
        return sha1;
    }
  }
}

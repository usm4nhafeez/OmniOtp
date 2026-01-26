import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import '../models/totp_account.dart';

/// TOTP Generator implementing RFC 6238
/// Time-based One-Time Password generator
class TotpService {
  /// Generate TOTP code for an account
  static String generateCode(TotpAccount account, {DateTime? time}) {
    final secret = base32Decode(account.secret);
    final counter = _getTimeCounter(time ?? DateTime.now(), account.period);
    return _generateHotp(
      secret,
      counter,
      account.digits,
      _getHashAlgorithm(account.algorithm),
    );
  }

  /// Get remaining seconds until next code refresh
  static int getRemainingSeconds({DateTime? time, int period = 30}) {
    final now = time ?? DateTime.now();
    final epochSeconds = now.millisecondsSinceEpoch ~/ 1000;
    return period - (epochSeconds % period);
  }

  /// Get the current time counter value
  static int _getTimeCounter(DateTime time, int period) {
    final epochSeconds = time.millisecondsSinceEpoch ~/ 1000;
    return epochSeconds ~/ period;
  }

  /// Generate HOTP code using the specified algorithm
  static String _generateHotp(
    Uint8List secret,
    int counter,
    int digits,
    Hash algorithm,
  ) {
    // Convert counter to 8-byte array (big-endian)
    final counterBytes = Uint8List(8);
    var tempCounter = counter;
    for (int i = 7; i >= 0; i--) {
      counterBytes[i] = tempCounter & 0xff;
      tempCounter >>= 8;
    }

    // Calculate HMAC
    final hmac = Hmac(algorithm, secret);
    final hash = Uint8List.fromList(hmac.convert(counterBytes).bytes);

    // Dynamic truncation
    final offset = hash[hash.length - 1] & 0x0f;
    final binary =
        ((hash[offset] & 0x7f) << 24) |
        ((hash[offset + 1] & 0xff) << 16) |
        ((hash[offset + 2] & 0xff) << 8) |
        (hash[offset + 3] & 0xff);

    // Generate OTP
    final otp = binary % _pow10(digits);
    return otp.toString().padLeft(digits, '0');
  }

  /// Get hash algorithm from TOTP algorithm enum
  static Hash _getHashAlgorithm(TotpAlgorithm algorithm) {
    switch (algorithm) {
      case TotpAlgorithm.sha256:
        return sha256;
      case TotpAlgorithm.sha512:
        return sha512;
      case TotpAlgorithm.md5:
        return md5;
      case TotpAlgorithm.sha1:
        return sha1;
    }
  }

  /// Calculate 10^digits
  static int _pow10(int digits) {
    int result = 1;
    for (int i = 0; i < digits; i++) {
      result *= 10;
    }
    return result;
  }

  /// Validate a TOTP secret format
  static bool isValidSecret(String secret) {
    try {
      final decoded = base32Decode(secret);
      return decoded.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Generate a new Base32 secret
  static String generateSecret({int length = 20}) {
    final random = DateTime.now().millisecondsSinceEpoch % 1000000;
    final bytes = utf8.encode('${random}_${DateTime.now().microsecond}');
    final hash = sha256.convert(bytes);
    final secret = base32Encode(
      Uint8List.fromList(
        hash.bytes.sublist(0, length.clamp(0, hash.bytes.length)),
      ),
    );
    return secret.substring(0, length);
  }
}

/// Base32 encoding/decoding utilities
class Base32 {
  static const String _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  static const List<int> _alphabetMap = [
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    26,
    27,
    28,
    29,
    30,
    31,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    0,
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
    23,
    24,
    25,
    255,
    255,
    255,
    255,
    255,
    255,
    0,
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
    23,
    24,
    25,
    255,
    255,
    255,
    255,
    255,
  ];

  /// Encode bytes to Base32 string
  static String encode(Uint8List data) {
    final result = StringBuffer();
    var buffer = 0;
    var bits = 0;

    for (final byte in data) {
      buffer = (buffer << 8) | byte;
      bits += 8;

      while (bits >= 5) {
        bits -= 5;
        result.write(_alphabet[(buffer >> bits) & 0x1F]);
      }
    }

    if (bits > 0) {
      result.write(_alphabet[(buffer << (5 - bits)) & 0x1F]);
    }

    return result.toString();
  }

  /// Decode Base32 string to bytes
  static Uint8List decode(String input) {
    final cleanInput = input.toUpperCase().replaceAll(RegExp(r'[^A-Z2-7]'), '');
    final result = <int>[];
    var buffer = 0;
    var bits = 0;

    for (final char in cleanInput.runes) {
      if (char > 127) continue;
      final value = _alphabetMap[char];
      if (value == 255) continue;

      buffer = (buffer << 5) | value;
      bits += 5;

      if (bits >= 8) {
        bits -= 8;
        result.add((buffer >> bits) & 0xFF);
      }
    }

    return Uint8List.fromList(result);
  }

  /// Normalize Base32 string
  static String normalize(String input) {
    return input
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z2-7]'), '')
        .replaceAllMapped(RegExp(r'.{8}'), (match) => '${match.group(0)} ')
        .trim();
  }
}

/// Backward compatibility alias
Uint8List base32Decode(String input) => Base32.decode(input);
String base32Encode(Uint8List input) => Base32.encode(input);

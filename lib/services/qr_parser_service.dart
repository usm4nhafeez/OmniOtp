import 'dart:core';

import '../models/totp_account.dart';
import 'totp_service.dart';

/// Parse otpauth:// URLs for TOTP configuration
/// Follows the Key Uri Format specification
class QrParserService {
  /// Parse an otpauth:// URI and return a TotpAccount
  static TotpAccount? parse(String uri) {
    if (!uri.toLowerCase().startsWith('otpauth://totp/')) {
      return null;
    }

    try {
      // Extract the path (contains issuer and account)
      final uriWithoutScheme = uri.substring(8); // Remove 'otpauth://'
      final pathEnd = uriWithoutScheme.indexOf('?');

      String path;
      Map<String, String> params;

      if (pathEnd == -1) {
        path = uriWithoutScheme;
        params = {};
      } else {
        path = uriWithoutScheme.substring(0, pathEnd);
        final queryString = uriWithoutScheme.substring(pathEnd + 1);
        params = _parseQueryString(queryString);
      }

      // Decode path (URL encoded)
      final decodedPath = _decodePathSegment(path);

      // Extract issuer and account from path
      String issuer;
      String accountName;

      if (decodedPath.contains(':')) {
        final parts = decodedPath.split(':');
        issuer = Uri.decodeComponent(parts[0]).trim();
        accountName = Uri.decodeComponent(parts[1]).trim();
      } else {
        // If no colon, check if issuer is in params
        issuer = params['issuer'] ?? 'Unknown';
        accountName = Uri.decodeComponent(decodedPath).trim();
      }

      // Extract required parameters
      final secret = params['secret'];
      if (secret == null || secret.isEmpty) {
        throw const FormatException('Missing required secret parameter');
      }

      // Normalize and validate secret
      final normalizedSecret = Base32.normalize(secret);
      if (!TotpService.isValidSecret(normalizedSecret)) {
        throw const FormatException('Invalid Base32 secret');
      }

      // Extract optional parameters
      final algorithm = _parseAlgorithm(params['algorithm']);
      final digits = int.tryParse(params['digits'] ?? '6') ?? 6;
      final period = int.tryParse(params['period'] ?? '30') ?? 30;

      // Validate parameters
      if (digits < 6 || digits > 8) {
        throw const FormatException('Digits must be between 6 and 8');
      }
      if (period < 15 || period > 60) {
        throw const FormatException('Period must be between 15 and 60 seconds');
      }

      return TotpAccount(
        issuer: issuer,
        accountName: accountName,
        secret: normalizedSecret,
        algorithm: algorithm,
        digits: digits,
        period: period,
      );
    } catch (e) {
      return null;
    }
  }

  /// Parse query string into key-value pairs
  static Map<String, String> _parseQueryString(String query) {
    final result = <String, String>{};
    final pairs = query.split('&');

    for (final pair in pairs) {
      final eqIndex = pair.indexOf('=');
      if (eqIndex == -1) continue;

      final key =
          Uri.decodeQueryComponent(pair.substring(0, eqIndex)).toLowerCase();
      final value = Uri.decodeQueryComponent(pair.substring(eqIndex + 1));
      result[key] = value;
    }

    return result;
  }

  /// Decode path segment handling URL encoding
  static String _decodePathSegment(String path) {
    // Handle URL-encoded characters
    return Uri.decodeComponent(path);
  }

  /// Parse algorithm string to TotpAlgorithm enum
  static TotpAlgorithm _parseAlgorithm(String? algorithm) {
    if (algorithm == null) return TotpAlgorithm.sha1;

    switch (algorithm.toUpperCase()) {
      case 'SHA256':
        return TotpAlgorithm.sha256;
      case 'SHA512':
        return TotpAlgorithm.sha512;
      case 'MD5':
        return TotpAlgorithm.md5;
      default:
        return TotpAlgorithm.sha1;
    }
  }

  /// Generate an otpauth:// URI for an account (for backup/export)
  static String generateUri(TotpAccount account) {
    final buffer = StringBuffer();
    buffer.write('otpauth://totp/');

    // Encode issuer:account
    buffer.write(
      Uri.encodeComponent('${account.issuer}:${account.accountName}'),
    );

    // Add parameters
    buffer.write('?secret=${account.secret}');
    buffer.write('&issuer=${Uri.encodeComponent(account.issuer)}');

    if (account.algorithm != TotpAlgorithm.sha1) {
      buffer.write(
        '&algorithm=${account.algorithm.toString().split('.').last.toUpperCase()}',
      );
    }

    if (account.digits != 6) {
      buffer.write('&digits=${account.digits}');
    }

    if (account.period != 30) {
      buffer.write('&period=${account.period}');
    }

    return buffer.toString();
  }

  /// Validate if a string is a valid TOTP URI
  static bool isValidTotpUri(String uri) {
    return parse(uri) != null;
  }

  /// Validate a manual secret entry
  static bool isValidManualSecret(String secret) {
    final normalized = Base32.normalize(secret);
    return TotpService.isValidSecret(normalized);
  }
}

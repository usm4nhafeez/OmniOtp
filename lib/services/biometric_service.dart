import 'package:local_auth/local_auth.dart';

/// Biometric authentication service
/// Provides app lock functionality using device biometrics
class BiometricService {
  final LocalAuthentication _localAuth;

  BiometricService({LocalAuthentication? localAuth})
    : _localAuth = localAuth ?? LocalAuthentication();

  /// Check if biometric authentication is available on the device
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (e) {
      return false;
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Authenticate using biometrics
  /// Returns true if authentication succeeds
  Future<bool> authenticate({
    String reason = 'Authenticate to access your authenticator',
    bool biometricOnly = true,
  }) async {
    try {
      return await _localAuth.authenticate(localizedReason: reason);
    } catch (e) {
      return false;
    }
  }

  /// Check if device supports biometric authentication
  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

  /// Check if biometric enrollment is set up
  Future<bool> isEnrolled() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  /// Sign out / cancel authentication session
  Future<void> stopAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } catch (e) {
      // Ignore errors
    }
  }
}

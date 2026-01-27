import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Firebase Authentication service
/// Handles user identity for cloud sync access using email/password
class AuthService {
  final FirebaseAuth _auth;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;

  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  /// Sign up with email and password
  Future<AuthResult> signUpWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      return AuthResult.success(
        userId: userCredential.user!.uid,
        email: userCredential.user?.email,
        displayName: userCredential.user?.displayName,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('SignUp Error: ${e.code} - ${e.message}');
      return AuthResult.error(_getErrorMessage(e.code));
    } catch (e) {
      debugPrint('SignUp Error: $e');
      return AuthResult.error('Sign up failed: $e');
    }
  }

  /// Sign in with email and password
  Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return AuthResult.success(
        userId: userCredential.user!.uid,
        email: userCredential.user?.email,
        displayName: userCredential.user?.displayName,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('SignIn Error: ${e.code} - ${e.message}');
      return AuthResult.error(_getErrorMessage(e.code));
    } catch (e) {
      debugPrint('SignIn Error: $e');
      return AuthResult.error('Sign in failed: $e');
    }
  }

  /// Send password reset email
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult.success(userId: '', email: email, displayName: null);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('Failed to send reset email');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Delete account
  Future<AuthResult> deleteAccount() async {
    try {
      await currentUser?.delete();
      return AuthResult.success(userId: '', email: null, displayName: null);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getErrorMessage(e.code));
    }
  }

  /// Re-authenticate with email/password (required for sensitive operations)
  Future<AuthResult> reauthenticateWithEmail(
    String email,
    String password,
  ) async {
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      await _auth.currentUser?.reauthenticateWithCredential(credential);
      return AuthResult.success(
        userId: _auth.currentUser!.uid,
        email: _auth.currentUser!.email,
        displayName: _auth.currentUser!.displayName,
      );
    } catch (e) {
      return AuthResult.error('Re-authentication failed');
    }
  }

  /// Get user ID for sync operations
  String? getUserId() {
    return _auth.currentUser?.uid;
  }

  /// Get user-friendly error messages
  String _getErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'Password is too weak (min 6 characters)';
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'invalid-credential':
        return 'Invalid email or password';
      default:
        return 'Authentication failed. Please try again';
    }
  }
}

/// Result of authentication operation
class AuthResult {
  final bool success;
  final String? userId;
  final String? email;
  final String? displayName;
  final String? errorMessage;
  final bool cancelled;

  AuthResult({
    required this.success,
    this.userId,
    this.email,
    this.displayName,
    this.errorMessage,
    this.cancelled = false,
  });

  factory AuthResult.success({
    required String userId,
    required String? email,
    required String? displayName,
  }) {
    return AuthResult(
      success: true,
      userId: userId,
      email: email,
      displayName: displayName,
    );
  }

  factory AuthResult.cancelled() {
    return AuthResult(
      success: false,
      cancelled: true,
      errorMessage: 'Sign in was cancelled',
    );
  }

  factory AuthResult.error(String message) {
    return AuthResult(success: false, errorMessage: message);
  }
}

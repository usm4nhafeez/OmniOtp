import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Firebase Authentication service
/// Handles user identity for cloud sync access
/// Authentication is NOT used as encryption key (per security requirements)
class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  // Stream for auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Current user getter
  User? get currentUser => _auth.currentUser;

  // Check if user is signed in
  bool get isSignedIn => _auth.currentUser != null;

  AuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
    : _auth = auth ?? FirebaseAuth.instance,
      _googleSignIn = googleSignIn ?? GoogleSignIn();

  /// Sign in with Google
  /// Returns the user ID for sync operations
  Future<AuthResult> signInWithGoogle() async {
    try {
      // Trigger Google Sign-In
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult.cancelled();
      }

      // Get auth credentials
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      await _auth.signInWithCredential(credential);

      return AuthResult.success(
        userId: _auth.currentUser!.uid,
        email: _auth.currentUser!.email,
        displayName: _auth.currentUser!.displayName,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(e.message ?? 'Sign in failed');
    } catch (e) {
      return AuthResult.error('An unexpected error occurred');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Delete account and all associated data
  Future<AuthResult> deleteAccount() async {
    try {
      await currentUser?.delete();
      return AuthResult.success(userId: '', email: null, displayName: null);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(e.message ?? 'Account deletion failed');
    }
  }

  /// Get user ID for sync operations
  String? getUserId() {
    return _auth.currentUser?.uid;
  }

  /// Re-authenticate (required for sensitive operations)
  Future<AuthResult> reauthenticateWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult.cancelled();
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
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

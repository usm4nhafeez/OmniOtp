# OmniOTP - Complete Documentation

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Firebase Setup](#firebase-setup)
4. [Security & Encryption](#security--encryption)
5. [Building & Deployment](#building--deployment)
6. [Chrome Extension](#chrome-extension)
7. [Troubleshooting](#troubleshooting)
8. [API Reference](#api-reference)

---

## Project Overview

**OmniOTP** is a cross-platform TOTP (Time-based One-Time Password) authenticator app with end-to-end encrypted cloud sync.

### Features

- ✅ **TOTP Generation**: RFC 6238 compliant, 6-digit codes, 30-second period
- ✅ **End-to-End Encryption**: AES-256-GCM encryption for all secrets
- ✅ **Cloud Sync**: Firebase Firestore with encrypted data storage
- ✅ **Email/Password Auth**: Firebase Authentication
- ✅ **Biometric Lock**: Fingerprint/Face ID support
- ✅ **QR Code Scanner**: Add accounts by scanning QR codes
- ✅ **Local Storage**: Works offline, encrypted local storage
- ✅ **Cross-Platform**: Flutter app (Android/iOS/macOS/Windows/Linux/Web) + Chrome Extension

### Tech Stack

**Mobile/Desktop App:**
- Flutter 3.38.5+
- Dart 3.10.4+
- Firebase Core 3.12.1
- Firebase Auth 5.5.2
- Cloud Firestore 5.6.6

**Chrome Extension:**
- Manifest V3
- Vanilla JavaScript (ES6 modules)
- Chrome Storage API
- Firebase JS SDK (optional)

---

## Architecture

### Project Structure

```
omniotp/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── firebase_options.dart     # Firebase configuration
│   ├── models/
│   │   └── totp_account.dart     # TOTP account model
│   ├── services/
│   │   ├── auth_service.dart           # Firebase Authentication
│   │   ├── biometric_service.dart      # Biometric lock
│   │   ├── cloud_sync_service.dart     # Firestore sync
│   │   ├── encryption_service.dart     # AES-256-GCM encryption
│   │   ├── local_storage_service.dart  # Secure local storage
│   │   ├── qr_parser_service.dart      # QR code parsing
│   │   └── totp_service.dart           # TOTP generation (RFC 6238)
│   ├── ui/
│   │   ├── components/
│   │   │   └── account_card.dart       # Account display widget
│   │   ├── screens/
│   │   │   ├── auth_screen.dart        # Sign in/up screen
│   │   │   ├── home_screen.dart        # Main accounts list
│   │   │   ├── add_account_screen.dart # Add new account
│   │   │   └── settings_screen.dart    # Settings & logout
│   │   └── theme/
│   │       └── app_theme.dart          # Material Design theme
│   └── utils/
├── android/                      # Android-specific files
├── ios/                          # iOS-specific files
├── extension/                    # Chrome extension
│   ├── manifest.json
│   ├── popup.html
│   ├── popup.js
│   ├── totp.js
│   ├── storage.js
│   └── firebase.js
├── firestore.rules               # Firestore security rules
├── firestore.indexes.json        # Firestore indexes
├── pubspec.yaml                  # Flutter dependencies
└── README.md
```

### Data Flow

```
User Input → UI Screens
           ↓
     Service Layer (Business Logic)
           ↓
    ┌──────┴──────┐
    ↓             ↓
Local Storage   Cloud Sync
(Encrypted)    (Firestore)
    ↓             ↓
Flutter         Firebase
Secure         Firestore
Storage        (Encrypted)
```

### Encryption Flow

```
TOTP Secret (plain) 
    ↓
AES-256-GCM Encryption
    ↓
Encrypted Blob + IV + Tag
    ↓
Stored Locally (flutter_secure_storage)
    ↓
Base64 Encoded
    ↓
Uploaded to Firestore /vaults/{userId}
```

---

## Firebase Setup

### 1. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Name it (e.g., "omniotp")
4. Disable Google Analytics (optional)
5. Click "Create project"

### 2. Enable Authentication

1. In Firebase Console, go to **Authentication**
2. Click "Get started"
3. Enable **Email/Password** provider
4. Click "Save"

### 3. Create Firestore Database

1. Go to **Firestore Database**
2. Click "Create database"
3. Choose **Production mode**
4. Select a location (e.g., us-central1)
5. Click "Enable"

### 4. Deploy Security Rules

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login
firebase login

# Initialize (in project root)
firebase init firestore

# Select your project
# Use existing firestore.rules and firestore.indexes.json

# Deploy rules and indexes
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

**Manual Deployment:**
1. In Firebase Console → Firestore Database → Rules
2. Copy content from `firestore.rules`
3. Click "Publish"

### 5. Add Flutter App

**Android:**
1. Firebase Console → Project Settings → Your apps
2. Click Android icon
3. Register app with package name: `com.omniotp.app` (or yours)
4. Download `google-services.json`
5. Place in `android/app/`

**iOS:**
1. Click iOS icon
2. Register with bundle ID: `com.omniotp.app`
3. Download `GoogleService-Info.plist`
4. Place in `ios/Runner/`

**Important:** Add these files to `.gitignore` (already done):
```
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
```

### 6. Generate Firebase Config

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Generate firebase_options.dart
flutterfire configure
```

This creates `lib/firebase_options.dart` with your project's configuration.

---

## Security & Encryption

### Encryption Algorithm

**AES-256-GCM (Galois/Counter Mode)**
- 256-bit key
- 96-bit IV (Initialization Vector)
- 128-bit authentication tag
- AEAD (Authenticated Encryption with Associated Data)

### Key Generation

```dart
// In EncryptionService.initialize()
1. Check if encryption key exists in secure storage
2. If not, generate random 256-bit key
3. Store in flutter_secure_storage (encrypted by OS)
4. Derive encryption key using PBKDF2 (optional, for master password)
```

### Encryption Process

```dart
// Encrypt TOTP accounts
accounts (List<Map>) 
    → JSON.encode() 
    → UTF-8 bytes 
    → AES-256-GCM encrypt 
    → Base64 encode 
    → Store/Upload
```

### Decryption Process

```dart
// Decrypt TOTP accounts
Base64 string 
    → Base64 decode 
    → AES-256-GCM decrypt 
    → UTF-8 decode 
    → JSON.parse() 
    → List<TotpAccount>
```

### Security Best Practices

1. **Never store secrets unencrypted**
2. **Encryption key never leaves device** (stored in OS keychain)
3. **Cloud data is encrypted client-side** (Firebase never sees plain secrets)
4. **Biometric authentication** for app access
5. **HTTPS only** for all network traffic
6. **No logging of sensitive data**

---

## Building & Deployment

### Prerequisites

```bash
# Check Flutter installation
flutter doctor

# Required versions
Flutter: >=3.38.5
Dart: >=3.10.4
```

### Install Dependencies

```bash
cd omniotp
flutter pub get
```

### Run in Development

```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Desktop (Windows/macOS/Linux)
flutter run -d windows
flutter run -d macos
flutter run -d linux

# Web
flutter run -d chrome
```

### Build Release APK (Android)

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

**For Google Play (AAB):**
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### Build iOS (App Store)

```bash
flutter build ios --release
# Then open ios/Runner.xcworkspace in Xcode
# Archive and upload to App Store Connect
```

### Android Signing

1. Create keystore:
```bash
keytool -genkey -v -keystore omniotp-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias omniotp
```

2. Create `android/key.properties`:
```properties
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=omniotp
storeFile=../omniotp-keystore.jks
```

3. Build signed APK:
```bash
flutter build apk --release
```

### GitHub Actions CI/CD

The project includes `.github/workflows/build-release.yml` for automated builds:

**Secrets to add in GitHub:**
- `ANDROID_KEYSTORE_BASE64` - Base64 encoded keystore
- `ANDROID_KEY_PROPERTIES` - key.properties content
- `GOOGLE_SERVICES_JSON` - google-services.json content (Android)
- `FIREBASE_PLIST` - GoogleService-Info.plist content (iOS)

**Trigger build:**
```bash
git tag v1.0.0
git push origin v1.0.0
```

---

## Chrome Extension

### Installation (Development)

1. Open Chrome → `chrome://extensions/`
2. Enable "Developer mode"
3. Click "Load unpacked"
4. Select `omniotp/extension/` folder

### Installation (Users)

Package and distribute as `.crx` file or publish to Chrome Web Store.

### Firebase Integration (Extension)

1. Add Firebase JS SDK to extension
2. Update `firebase.js` with your Firebase config
3. Use same Firestore structure as mobile app

### Security Considerations

- Secrets stored in Chrome Storage API (unencrypted)
- Consider adding encryption layer for production
- Extension has access to same Firebase backend
- Use content security policy to prevent XSS

### Testing Extension

1. Make changes to extension files
2. Go to `chrome://extensions/`
3. Click reload icon
4. Open extension popup to test

---

## Troubleshooting

### Common Issues

#### 1. "Permission denied" when syncing

**Problem:** Firestore rules not deployed or incorrect

**Solution:**
```bash
# Deploy rules
firebase deploy --only firestore:rules

# Or manually update in Firebase Console
```

Ensure rules in `firestore.rules` match:
```javascript
match /vaults/{userId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

#### 2. "Flutter version mismatch"

**Problem:** pubspec.yaml requires newer Flutter

**Solution:**
```bash
flutter upgrade
flutter pub get
```

#### 3. "Google Sign-In failed"

**Problem:** This version uses email/password (Google Sign-In was removed)

**Solution:** Use email/password authentication

#### 4. Build failures on Android

**Problem:** Gradle or dependency issues

**Solution:**
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk
```

#### 5. "No Firebase App" error

**Problem:** Firebase not initialized

**Solution:**
1. Ensure `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) exists
2. Run `flutterfire configure` to regenerate config
3. Check `firebase_options.dart` is imported in `main.dart`

### Debug Mode

Enable debug logging:
```dart
// In services, add:
debugPrint('Log message');

// Run app with:
flutter run --debug
```

### Firestore Debugging

View data in Firebase Console:
- Firestore Database → Data tab
- Check `/vaults/{userId}` documents
- Verify `encryptedData` field exists

---

## API Reference

### AuthService

```dart
class AuthService {
  // Sign up with email/password
  Future<AuthResult> signUpWithEmail(String email, String password);
  
  // Sign in
  Future<AuthResult> signInWithEmail(String email, String password);
  
  // Sign out
  Future<void> signOut();
  
  // Password reset
  Future<AuthResult> sendPasswordResetEmail(String email);
  
  // Delete account
  Future<AuthResult> deleteAccount();
  
  // Get current user ID
  String? getUserId();
  
  // Check if signed in
  bool get isSignedIn;
}
```

### EncryptionService

```dart
class EncryptionService {
  // Initialize (generate or load key)
  Future<void> initialize();
  
  // Encrypt accounts to Base64 string
  Future<String> encryptAccounts(List<Map<String, dynamic>> accounts);
  
  // Decrypt Base64 string to accounts
  Future<List<Map<String, dynamic>>> decryptAccounts(String encryptedData);
}
```

### CloudSyncService

```dart
class CloudSyncService {
  // Upload encrypted data to Firestore
  Future<void> syncToCloud(String userId, List<TotpAccount> accounts);
  
  // Download and decrypt from Firestore
  Future<List<TotpAccount>> syncFromCloud(String userId);
  
  // Two-way sync (merge local + cloud)
  Future<SyncResult> performSync(String userId);
  
  // Delete cloud vault
  Future<void> deleteCloudVault(String userId);
}
```

### TotpService

```dart
class TotpService {
  // Generate 6-digit TOTP code
  static String generateCode(TotpAccount account);
  
  // Parse otpauth:// URL
  static TotpAccount? parseOtpAuthUrl(String url);
  
  // Get remaining seconds in current period
  static int getRemainingSeconds();
}
```

### LocalStorageService

```dart
class LocalStorageService {
  // Load all accounts from secure storage
  Future<List<TotpAccount>> loadAccounts();
  
  // Save all accounts
  Future<void> saveAccounts(List<TotpAccount> accounts);
  
  // Add single account
  Future<void> addAccount(TotpAccount account);
  
  // Delete account
  Future<void> deleteAccount(String accountId);
}
```

### BiometricService

```dart
class BiometricService {
  // Check if biometric available
  Future<bool> isBiometricAvailable();
  
  // Authenticate with biometric
  Future<bool> authenticate({required String reason});
  
  // Stop authentication session
  Future<void> stopAuthentication();
}
```

### TotpAccount Model

```dart
class TotpAccount {
  final String id;
  final String issuer;         // e.g., "Google"
  final String accountName;    // e.g., "user@gmail.com"
  final String secret;         // Base32 encoded secret
  final String algorithm;      // "SHA1", "SHA256", "SHA512"
  final int digits;            // Usually 6
  final int period;            // Usually 30 seconds
  final int createdAt;
  final int updatedAt;
  
  // Convert to/from JSON
  Map<String, dynamic> toJson();
  factory TotpAccount.fromJson(Map<String, dynamic> json);
  
  // Convert to/from vault format (encrypted storage)
  Map<String, dynamic> toVaultMap();
  factory TotpAccount.fromVaultMap(Map<String, dynamic> map);
}
```

---

## Firebase Rules Explained

### Firestore Rules (firestore.rules)

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    // User vaults - stores encrypted TOTP data
    match /vaults/{userId} {
      // Only allow access if:
      // 1. User is authenticated (request.auth != null)
      // 2. User ID matches document ID (request.auth.uid == userId)
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Deny all other access by default
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

**Key Points:**
- Each user has ONE document: `/vaults/{userId}`
- Document contains `encryptedData` (Base64 string)
- Users can only access their own vault
- Firebase never decrypts the data

### Firestore Indexes (firestore.indexes.json)

```json
{
  "indexes": [],
  "fieldOverrides": []
}
```

No indexes needed currently since we only read/write single documents.

---

## Manual Firestore Setup

If you prefer manual setup instead of `firebase deploy`:

### 1. Create Firestore Database

1. Firebase Console → Firestore Database
2. Click "Create database"
3. Production mode
4. Choose location

### 2. Add Security Rules

1. Go to Rules tab
2. Replace with content from `firestore.rules`
3. Click "Publish"

### 3. Test Rules

In Firestore → Rules → Rules Playground:

**Test read (should succeed):**
```
Location: /vaults/test-user-123
Auth: {uid: "test-user-123"}
Type: get
```

**Test write (should succeed):**
```
Location: /vaults/test-user-123
Auth: {uid: "test-user-123"}
Type: set
Data: {encryptedData: "test"}
```

**Test unauthorized (should fail):**
```
Location: /vaults/test-user-123
Auth: {uid: "different-user"}
Type: get
```

---

## Understanding the Code (For Non-Developers)

### What is TOTP?

TOTP (Time-based One-Time Password) generates a 6-digit code that changes every 30 seconds.

**How it works:**
1. You scan a QR code or enter a secret key
2. The app uses a mathematical formula with:
   - The secret key
   - Current time
3. Result: 6-digit code (e.g., 123456)
4. Same formula on server = same code
5. After 30 seconds, time changes → new code

### What is Encryption?

Think of it like a locked safe:
- **Plain text** = your TOTP secrets (the valuables)
- **Encryption** = locking them in a safe
- **Encryption key** = the safe's combination (stored on your device)
- **Encrypted data** = the locked safe (stored in cloud)

**Why it matters:**
- Even if someone hacks Firebase, they get encrypted gibberish
- Only YOU have the key (on your device)
- Not even Firebase admins can see your secrets

### What is Firebase?

Firebase is Google's cloud service that provides:
1. **Authentication** - verifies you are who you say you are
2. **Firestore** - database to store your encrypted data
3. **Sync** - keeps your accounts in sync across devices

### How Sync Works

```
Phone A              Firebase Cloud              Phone B
  |                        |                        |
  | 1. Encrypt data        |                        |
  |----------------------->|                        |
  |                        | 2. Store encrypted     |
  |                        |<-----------------------|
  |                        | 3. Download encrypted  |
  |<-----------------------|                        |
  | 4. Decrypt data        |                        |
```

### File Explanations

**lib/main.dart** - Entry point, starts the app
**lib/services/** - Business logic (encryption, sync, etc.)
**lib/ui/screens/** - What you see (sign in, home, settings)
**lib/models/** - Data structures (how accounts are stored)
**pubspec.yaml** - List of dependencies (libraries we use)
**firestore.rules** - Security rules (who can access what)

---

## FAQ

**Q: Can I use this without creating a Firebase account?**
A: Yes! Click "Use without account" - data stays on your device only.

**Q: Is my data safe?**
A: Yes, all secrets are encrypted with AES-256-GCM before leaving your device.

**Q: Can Firebase employees see my TOTP secrets?**
A: No, they only see encrypted data. Only you have the decryption key.

**Q: What happens if I lose my phone?**
A: If you signed in, your encrypted data is in Firebase. Sign in on a new device to restore.

**Q: What if I didn't sign in?**
A: Data is lost. Always create a backup or use cloud sync.

**Q: Can I export my accounts?**
A: Not yet, but it's on the roadmap.

**Q: Does this work offline?**
A: Yes, TOTP generation works offline. Sync requires internet.

**Q: How is this different from Google Authenticator?**
A: 
- End-to-end encrypted cloud sync
- Cross-platform (mobile + desktop + extension)
- Open source
- Biometric lock

---

## Support & Contributing

**Issues:** Open an issue on GitHub
**Contributions:** Pull requests welcome!
**License:** MIT (or your chosen license)

---

**Last Updated:** January 2026
**Version:** 1.0.0

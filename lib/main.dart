import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/biometric_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/encryption_service.dart';
import 'services/local_storage_service.dart';
import 'services/totp_service.dart';
import 'models/totp_account.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/auth_screen.dart';
import 'ui/screens/add_account_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize encryption service
  final encryptionService = EncryptionService();
  await encryptionService.initialize();

  // Initialize auth service
  final authService = AuthService();

  final biometricService = BiometricService();
  final localStorageService = LocalStorageService(
    encryption: encryptionService,
  );
  final cloudSyncService = CloudSyncService(
    encryption: encryptionService,
    localStorage: localStorageService,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: encryptionService),
        Provider.value(value: authService),
        Provider.value(value: biometricService),
        Provider.value(value: localStorageService),
        Provider.value(value: cloudSyncService),
        ChangeNotifierProvider(
          create: (context) =>
              TotpProvider(localStorageService, cloudSyncService, authService),
        ),
      ],
      child: const OmniOtpApp(),
    ),
  );
}

/// Main application widget
class OmniOtpApp extends StatelessWidget {
  const OmniOtpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OmniOTP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', 'US')],
      home: const AuthWrapper(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/add-account': (context) => const AddAccountScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

/// Authentication wrapper - handles biometric and Firebase auth
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isAuthenticated = false;
  bool _isLoading = true;
  bool _biometricRequired = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final biometricService = context.read<BiometricService>();
    final authService = context.read<AuthService>();

    // Check if biometric is available and preferred
    final isBiometricAvailable = await biometricService.isBiometricAvailable();
    final prefs = await SharedPreferences.getInstance();
    final useBiometric = prefs.getBool('use_biometric') ?? false;

    if (isBiometricAvailable && useBiometric) {
      // Biometric is required - must authenticate
      setState(() => _biometricRequired = true);

      final success = await biometricService.authenticate(
        reason: 'Unlock OmniOTP',
      );
      if (mounted) {
        setState(() {
          _isAuthenticated = success;
          _isLoading = false;
        });
      }
    } else if (authService.isSignedIn) {
      // User is signed in to Firebase, no biometric required
      if (mounted) {
        setState(() {
          _isAuthenticated = true;
          _isLoading = false;
        });
      }
    } else {
      // No biometric required and not signed in - show auth screen
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _retryBiometric() async {
    final biometricService = context.read<BiometricService>();
    final success = await biometricService.authenticate(
      reason: 'Unlock OmniOTP',
    );
    if (mounted && success) {
      setState(() => _isAuthenticated = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // If biometric is required but failed, show locked screen
    if (_biometricRequired && !_isAuthenticated) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 80, color: Colors.grey),
                const SizedBox(height: 24),
                Text(
                  'OmniOTP is Locked',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Authenticate to access your accounts',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _retryBiometric,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Unlock with Biometrics'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isAuthenticated) {
      return const AuthScreen();
    }

    return const HomeScreen();
  }
}

/// TOTP Provider for state management
class TotpProvider with ChangeNotifier {
  final LocalStorageService _localStorage;
  final CloudSyncService _cloudSync;
  final AuthService _auth;

  List<TotpAccount> _accounts = [];
  int _remainingSeconds = 30;

  TotpProvider(this._localStorage, this._cloudSync, this._auth);

  List<TotpAccount> get accounts => _accounts;
  int get remainingSeconds => _remainingSeconds;

  Future<void> loadAccounts() async {
    _accounts = await _localStorage.loadAccounts();
    notifyListeners();
    _startTimer();
  }

  Future<void> addAccount(TotpAccount account) async {
    await _localStorage.addAccount(account);
    await loadAccounts();

    // Sync to cloud if signed in and sync encryption is ready
    if (_auth.isSignedIn && _cloudSync.isSyncReady) {
      try {
        await _cloudSync.syncToCloud(_auth.getUserId()!, _accounts);
      } catch (e) {
        debugPrint('Cloud sync failed: $e');
      }
    }
  }

  Future<void> deleteAccount(String accountId) async {
    await _localStorage.deleteAccount(accountId);
    await loadAccounts();

    // Sync to cloud if signed in and sync encryption is ready
    if (_auth.isSignedIn && _cloudSync.isSyncReady) {
      try {
        await _cloudSync.syncToCloud(_auth.getUserId()!, _accounts);
      } catch (e) {
        debugPrint('Cloud sync failed: $e');
      }
    }
  }

  String getOtpForAccount(TotpAccount account) {
    return TotpService.generateCode(account);
  }

  void _startTimer() {
    Future.doWhile(() async {
      _remainingSeconds = TotpService.getRemainingSeconds();
      notifyListeners();
      await Future.delayed(const Duration(seconds: 1));
      return !(_accounts.isEmpty && _remainingSeconds == 30);
    });
  }

  Future<void> syncWithCloud() async {
    if (!_auth.isSignedIn) return;
    if (!_cloudSync.isSyncReady) {
      debugPrint('Sync encryption not ready - user needs to sign in again');
      return;
    }
    await _cloudSync.performSync(_auth.getUserId()!);
    await loadAccounts();
  }
}

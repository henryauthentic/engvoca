import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'services/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/verify_email_screen.dart';
import 'utils/constants.dart';
import 'db/database_helper.dart';
import 'services/sync_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'screens/splash_screen.dart';
// ✅ NEW imports
import 'providers/onboarding_provider.dart';
import 'providers/study_timer_provider.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'theme/app_theme.dart';


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => OnboardingProvider()),
        ChangeNotifierProvider(create: (_) => StudyTimerProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: AppStrings.appName,
            debugShowCheckedModeBanner: false,
            
            // ⭐ Theme Mode
            themeMode: themeProvider.themeMode,
            
            // ⭐ Light Theme
            theme: AppTheme.lightTheme,
            
            // ⭐ Dark Theme
            darkTheme: AppTheme.darkTheme,
            
            routes: {
              '/': (context) => const SplashScreen(),   // ⭐ Splash là màn đầu tiên
              '/auth': (context) => const AuthWrapper(), // ⭐ AuthWrapper dời sang route khác
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const HomeScreen(),
              '/verify': (context) => const VerifyEmailScreen(),
              '/onboarding': (context) => const OnboardingScreen(),
            },
            initialRoute: '/',
          );
        },
      ),
    );
  }

}

// ============================================
// AuthWrapper: login → onboarding check → home
// ============================================
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _dbHelper = DatabaseHelper.instance;
  final _syncService = SyncService();
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    // ✅ Đợi 100ms để tránh rebuild quá nhanh
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (!mounted) return;
    
    setState(() {
      _isCheckingAuth = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return StreamBuilder<auth.User?>(
      stream: auth.FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // ✅ Đang loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // ✅ Không có user → Login
        if (!snapshot.hasData || snapshot.data == null) {
          _dbHelper.setCurrentUser(null);
          return const LoginScreen();
        }

        // ✅ Có user → Check email verification
        final user = snapshot.data!;
        _dbHelper.setCurrentUser(user.uid);
        print('🔐 User logged in: ${user.uid}');

        // ✅ Kiểm tra email verified
        final isVerified = user.emailVerified;
        print('📧 Email verified: $isVerified');

        if (!isVerified) {
          return const VerifyEmailScreen();
        }

        // ✅ Start auto-sync timer if enabled
        _syncService.startAutoSyncTimer(user.uid);

        // ✅ NEW: Check onboarding status
        return FutureBuilder<Map<String, dynamic>?>(
          future: _dbHelper.getLocalUser(user.uid),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                body: const Center(child: CircularProgressIndicator()),
              );
            }

            final userData = userSnapshot.data;
            final isOnboarded = userData?['is_onboarded'] == 1;

            if (!isOnboarded) {
              return const OnboardingScreen();
            }

            return const HomeScreen();
          },
        );
      },
    );
  }
}
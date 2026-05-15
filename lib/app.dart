import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'services/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/verify_email_screen.dart';
import 'utils/constants.dart';
import 'db/database_helper.dart';
import 'firebase/firebase_service.dart';
import 'services/sync_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'screens/splash_screen.dart';
// ✅ NEW imports
import 'providers/onboarding_provider.dart';
import 'providers/study_timer_provider.dart';
import 'services/system_config_service.dart';
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
        ChangeNotifierProvider(create: (_) => SystemConfigService()),
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
// ✅ FIX: Check Firebase nếu SQLite chưa có onboarding data
// ============================================
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _dbHelper = DatabaseHelper.instance;
  final _firebaseService = FirebaseService();
  final _syncService = SyncService();
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    setState(() => _isCheckingAuth = false);
  }

  /// ✅ Check onboarding: SQLite trước → nếu chưa có thì check Firebase
  Future<bool> _checkOnboardingStatus(String userId) async {
    // 1. Check SQLite (nhanh, offline)
    final userData = await _dbHelper.getLocalUser(userId);
    if (userData != null && userData['is_onboarded'] == 1) {
      return true;
    }

    // 2. SQLite chưa có data → check Firebase (cloud)
    try {
      final firebaseUser = await _firebaseService.getUser(userId);
      
      // ✅ Nếu user có cắm cờ isOnboarded HOẶC đã có dữ liệu học tập (từ Web sang) thì coi như đã onboard
      final hasData = (firebaseUser?.learnedWords ?? 0) > 0 || 
                      (firebaseUser?.totalWords ?? 0) > 0 ||
                      (firebaseUser?.currentStreak ?? 0) > 0;
                      
      if (firebaseUser != null && (firebaseUser.isOnboarded || hasData)) {
        // ✅ Firebase đã onboarded → sync về SQLite
        print('🔄 Firebase has onboarding=true (or has data), syncing to SQLite...');
        await _dbHelper.upsertUser(
          id: userId,
          name: firebaseUser.displayName,
          email: firebaseUser.email,
          avatarUrl: firebaseUser.avatar,
          wordsLearned: firebaseUser.learnedWords,
          totalPoints: firebaseUser.totalXp,
          streakDays: firebaseUser.currentStreak,
          longestStreak: firebaseUser.longestStreak,
          usedGracePeriod: firebaseUser.usedGracePeriod,
          isOnboarded: true,
          learningLevel: firebaseUser.learningLevel,
          selectedTopics: firebaseUser.selectedTopics?.join(','),
          dailyGoal: firebaseUser.dailyGoal ?? 20,
          lastStudyDate: firebaseUser.lastStudyDate,
        );
        print('✅ Onboarding data synced from Firebase → SQLite');
        return true;
      }
    } catch (e) {
      print('⚠️ Error checking Firebase onboarding: $e');
    }

    return false; // Chưa onboarded ở cả 2 nơi
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<auth.User?>(
      stream: auth.FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Đang loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        // Không có user → Login
        if (!snapshot.hasData || snapshot.data == null) {
          _dbHelper.setCurrentUser(null);
          return const LoginScreen();
        }

        // Có user → Check email verification
        final user = snapshot.data!;
        _dbHelper.setCurrentUser(user.uid);

        if (!user.emailVerified) {
          return const VerifyEmailScreen();
        }

        // Start auto-sync timer if enabled
        _syncService.startAutoSyncTimer(user.uid);

        // ✅ Check onboarding (SQLite → Firebase fallback)
        return FutureBuilder<bool>(
          future: _checkOnboardingStatus(user.uid),
          builder: (context, onboardingSnapshot) {
            if (onboardingSnapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                body: const Center(child: CircularProgressIndicator()),
              );
            }

            final isOnboarded = onboardingSnapshot.data ?? false;

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
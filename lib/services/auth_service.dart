// ============================================
// FILE: lib/services/auth_service.dart
// ✅ Pure Mobile implementation
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';
import '../firebase/firebase_service.dart';
import '../db/database_helper.dart';
import 'sync_service.dart'; 

class AuthService {
  final auth.FirebaseAuth _firebaseAuth = auth.FirebaseAuth.instance;
  final FirebaseService _firebaseService = FirebaseService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final SyncService _syncService = SyncService(); 

  auth.User? get currentUser => _firebaseAuth.currentUser;
  Stream<auth.User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// ======================================
  /// LOGIN - ✅ FIXED VERSION
  /// ======================================
  Future<User> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw Exception("Đăng nhập thất bại");
      }

      _dbHelper.setCurrentUser(firebaseUser.uid);
      print('🔐 Set database user to: ${firebaseUser.uid}');

      // ✅ 1. Lấy thông tin user từ Firebase
      final user = await _firebaseService.getUser(firebaseUser.uid);
      if (user == null) {
        throw Exception("Không tìm thấy dữ liệu người dùng");
      }

      print('📥 User from Firebase: totalWords=${user.totalWords}, learnedWords=${user.learnedWords}');

      // ✅ 2. Lưu user info (bao gồm onboarding data)
      await _dbHelper.upsertUser(
        id: firebaseUser.uid,
        name: user.displayName,
        email: user.email,
        avatarUrl: user.avatar,
        wordsLearned: user.learnedWords,
        totalPoints: user.totalXp,
        streakDays: user.currentStreak,
        longestStreak: user.longestStreak,
        lastStudyDate: user.lastStudyDate,
        // ✅ Thông minh: Nếu user Firebase có isOnboarded = false (do lỗi cũ) nhưng có data thì coi như đã onboarded
        isOnboarded: user.isOnboarded || user.learnedWords > 0 || user.totalWords > 0 || user.currentStreak > 0,
        learningLevel: user.learningLevel,
        selectedTopics: user.selectedTopics.isNotEmpty 
            ? user.selectedTopics.join(',') 
            : null,
        dailyGoal: user.dailyGoal,
      );

      // ✅ 3. Sync SQLite progress
      print('🔄 Syncing learned words from Firebase...');
      await _syncService.downloadProgress(firebaseUser.uid);

      print('📊 Updating local topic counts...');
      await _dbHelper.updateTopicCounts();

      // ✅ 4. Verify data
      final topics = await _dbHelper.getParentTopics();
      final localTotal = topics.fold(0, (sum, t) => sum + t.wordCount);
      final localLearned = topics.fold(0, (sum, t) => sum + t.learnedCount);
      print('✅ Data after login: total=$localTotal, learned=$localLearned');

      // ✅ 5. Update lastLoginAt trên Firebase (KHÔNG ghi đè learnedWords/totalWords)
      await _firebaseService.updateLastLogin(user.id);

      return user;
    } on auth.FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// ======================================
  /// GOOGLE SIGN IN - ✅ FIXED VERSION
  /// ======================================
  Future<User> signInWithGoogle() async {

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        throw Exception('Đăng nhập Google bị hủy');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception("Đăng nhập Google thất bại");
      }

      _dbHelper.setCurrentUser(firebaseUser.uid);
      print('🔐 Set database user to: ${firebaseUser.uid}');

      User? user = await _firebaseService.getUser(firebaseUser.uid);

      if (user == null) {
        // Người dùng mới
        user = User(
          id: firebaseUser.uid,
          email: firebaseUser.email!,
          displayName: firebaseUser.displayName ?? 'Google User',
          avatar: firebaseUser.photoURL ?? "assets/images/default_avatar.png",
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        );

        await _firebaseService.createUser(user);
        print('✅ Created new user from Google Sign-In');
      } else {
        // Người dùng cũ - sync data
        print('📥 Existing user from Firebase: totalWords=${user.totalWords}, learnedWords=${user.learnedWords}');
        
        // ✅ Cập nhật Avatar nếu user cũ đang dùng avatar mặc định nhưng Google cung cấp photoURL mới
        if (firebaseUser.photoURL != null && 
            (user.avatar.isEmpty || user.avatar.contains('default_avatar.png'))) {
          user = user.copyWith(avatar: firebaseUser.photoURL);
          await _firebaseService.updateUser(user);
          print('🖼️ Updated user avatar from Google Sign-In');
        }

        // ✅ Sync SQLite
        print('🔄 Syncing learned words from Firebase...');
        await _syncService.downloadProgress(firebaseUser.uid);
        print('📊 Updating local topic counts...');
        await _dbHelper.updateTopicCounts();

        // ✅ Verify data
        final topics = await _dbHelper.getParentTopics();
        final localTotal = topics.fold(0, (sum, t) => sum + t.wordCount);
        final localLearned = topics.fold(0, (sum, t) => sum + t.learnedCount);
        print('✅ Data after sync: total=$localTotal, learned=$localLearned');

        // ✅ Update lastLoginAt (KHÔNG ghi đè learnedWords/totalWords)
        await _firebaseService.updateLastLogin(user.id);
      }

      // ✅ Lưu user vào SQLite (bao gồm onboarding data)
      await _dbHelper.upsertUser(
        id: firebaseUser.uid,
        name: user.displayName,
        email: user.email,
        avatarUrl: user.avatar,
        wordsLearned: user.learnedWords,
        totalPoints: user.totalXp,
        streakDays: user.currentStreak,
        longestStreak: user.longestStreak,
        lastStudyDate: user.lastStudyDate,
        // ✅ Thông minh: Nếu user Firebase có isOnboarded = false (do lỗi cũ) nhưng có data thì coi như đã onboarded
        isOnboarded: user.isOnboarded || user.learnedWords > 0 || user.totalWords > 0 || user.currentStreak > 0,
        learningLevel: user.learningLevel,
        selectedTopics: user.selectedTopics.isNotEmpty 
            ? user.selectedTopics.join(',') 
            : null,
        dailyGoal: user.dailyGoal,
      );

      return user;
    } on auth.FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Lỗi đăng nhập Google: ${e.toString()}');
    }
  }

  /// ======================================
  /// REGISTER (giữ nguyên)
  /// ======================================
  Future<User> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw Exception("Đăng ký thất bại");
      }

      await firebaseUser.updateDisplayName(displayName);
      await firebaseUser.sendEmailVerification();

      _dbHelper.setCurrentUser(firebaseUser.uid);

      final user = User(
        id: firebaseUser.uid,
        email: email,
        displayName: displayName,
        avatar: "assets/images/default_avatar.png",
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );

      await _firebaseService.createUser(user);
      
      await _dbHelper.upsertUser(
        id: firebaseUser.uid,
        name: displayName,
        email: email,
        avatarUrl: "assets/images/default_avatar.png",
      );
      
      return user;
    } on auth.FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// ======================================
  /// LOGOUT (giữ nguyên)
  /// ======================================
  Future<void> logout() async {
    final userId = _firebaseAuth.currentUser?.uid;
    
    if (userId != null) {
      await _dbHelper.deleteLocalUser(userId);
    }
    
    _dbHelper.setCurrentUser(null);
    print('🔐 Cleared database user');
    
    await Future.wait([
      _firebaseAuth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  /// ======================================
  /// EMAIL VERIFICATION
  /// ======================================
  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  bool get isEmailVerified =>
      _firebaseAuth.currentUser?.emailVerified ?? false;

  Future<void> reloadUser() async {
    await _firebaseAuth.currentUser?.reload();
  }

  /// ======================================
  /// FORGOT PASSWORD
  /// ======================================
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on auth.FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// ======================================
  /// CHANGE PASSWORD
  /// ======================================
  Future<void> changePassword(String newPassword) async {
    try {
      await _firebaseAuth.currentUser?.updatePassword(newPassword);
    } on auth.FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// ======================================
  /// ERROR HANDLER
  /// ======================================
  String _handleAuthException(auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Mật khẩu quá yếu';
      case 'email-already-in-use':
        return 'Email đã được sử dụng';
      case 'user-not-found':
        return 'Không tìm thấy tài khoản';
      case 'wrong-password':
        return 'Sai mật khẩu';
      case 'invalid-email':
        return 'Email không hợp lệ';
      case 'user-disabled':
        return 'Tài khoản đã bị vô hiệu hóa';
      case 'too-many-requests':
        return 'Quá nhiều yêu cầu. Thử lại sau.';
      case 'operation-not-allowed':
        return 'Phương thức đăng nhập chưa được bật trong Firebase';
      case 'account-exists-with-different-credential':
        return 'Tài khoản đã tồn tại với phương thức đăng nhập khác';
      case 'invalid-credential':
        return 'Thông tin xác thực không hợp lệ';
      case 'network-request-failed':
        return 'Lỗi kết nối mạng. Vui lòng thử lại.';
      default:
        return e.message ?? 'Đã xảy ra lỗi không xác định';
    }
  }
}
import 'package:flutter/material.dart';

class AppConstants {
  // ==========================================
  // LIGHT THEME COLORS
  // ==========================================
  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color secondaryColor = Color(0xFF2ECC71);
  static const Color errorColor = Color(0xFFE74C3C);
  static const Color backgroundColor = Color(0xFFF8F9FA);
  static const Color cardColor = Colors.white;
  
  // ==========================================
  // DARK THEME COLORS
  // ==========================================
  static const Color darkPrimaryColor = Color(0xFF8B82FF);
  static const Color darkSecondaryColor = Color(0xFF3DDC84);
  static const Color darkErrorColor = Color(0xFFFF5252);
  static const Color darkBackgroundColor = Color(0xFF121212);
  static const Color darkCardColor = Color(0xFF1E1E1E);
  static const Color darkSurfaceColor = Color(0xFF2C2C2C);
  
  // Text colors for dark mode
  static const Color darkTextPrimary = Color(0xFFE1E1E1);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);
  static const Color darkTextTertiary = Color(0xFF808080);
  
  // ==========================================
  // TEXT STYLES (will adapt to theme)
  // ==========================================
  static const TextStyle titleStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );
  
  static const TextStyle subtitleStyle = TextStyle(
    fontSize: 16,
  );
  
  static const TextStyle bodyStyle = TextStyle(
    fontSize: 14,
  );

  // ==========================================
  // SPACING
  // ==========================================
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;

  // ==========================================
  // QUIZ SETTINGS
  // ==========================================
  static const int questionsPerQuiz = 10;
  static const int quizTimeLimit = 300; // 5 minutes in seconds
  
  // ==========================================
  // ANIMATION DURATIONS
  // ==========================================
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
  
  // ==========================================
  // HELPER METHODS
  // ==========================================
  
  /// Get primary color based on theme brightness
  static Color getPrimaryColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkPrimaryColor
        : primaryColor;
  }
  
  /// Get background color based on theme brightness
  static Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBackgroundColor
        : backgroundColor;
  }
  
  /// Get card color based on theme brightness
  static Color getCardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkCardColor
        : cardColor;
  }
}

// ==========================================
// APP STRINGS
// ==========================================
class AppStrings {
  static const String appName = 'ENG VOCA';
  static const String login = 'Đăng nhập';
  static const String register = 'Đăng ký';
  static const String email = 'Email';
  static const String password = 'Mật khẩu';
  static const String confirmPassword = 'Xác nhận mật khẩu';
  static const String displayName = 'Tên hiển thị';
  static const String forgotPassword = 'Quên mật khẩu?';
  static const String dontHaveAccount = 'Chưa có tài khoản?';
  static const String alreadyHaveAccount = 'Đã có tài khoản?';
  static const String logout = 'Đăng xuất';
  
  static const String home = 'Trang chủ';
  static const String progress = 'Tiến độ';
  static const String settings = 'Cài đặt';
  
  static const String topics = 'Chủ đề';
  static const String words = 'Từ vựng';
  static const String quiz = 'Kiểm tra';
  
  static const String learned = 'Đã học';
  static const String notLearned = 'Chưa học';
  static const String reviewCount = 'Số lần ôn';
  
  static const String startQuiz = 'Bắt đầu';
  static const String submit = 'Nộp bài';
  static const String next = 'Tiếp theo';
  static const String previous = 'Trước';
  static const String finish = 'Hoàn thành';
  
  static const String score = 'Điểm';
  static const String correct = 'Đúng';
  static const String incorrect = 'Sai';
  static const String timeSpent = 'Thời gian';
  
  static const String syncData = 'Đồng bộ dữ liệu';
  static const String lastSync = 'Lần đồng bộ cuối';
  
  static const String error = 'Lỗi';
  static const String success = 'Thành công';
  static const String loading = 'Đang tải...';
}
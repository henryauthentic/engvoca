import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../theme/theme_extensions.dart';
import '../widgets/common/app_card.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trợ giúp'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppConstants.paddingLarge),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  context.primaryColor,
                  context.primaryColor.withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.help_center,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Bạn cần giúp gì?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Dưới đây là các câu hỏi thường gặp',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.paddingLarge),

          // FAQ List
          _buildFAQCard(context: context, icon: Icons.account_circle,
            question: 'Làm sao để thay đổi thông tin cá nhân?',
            answer: 'Vào Cài đặt > Thông tin cá nhân để thay đổi tên hiển thị và ảnh đại diện.',
            isDark: isDark),
          _buildFAQCard(context: context, icon: Icons.book,
            question: 'Làm sao để bắt đầu học từ vựng?',
            answer: 'Chọn một chủ đề từ trang chủ, sau đó chọn chế độ học phù hợp: Flashcard, Quiz hoặc Ôn tập.',
            isDark: isDark),
          _buildFAQCard(context: context, icon: Icons.sync,
            question: 'Dữ liệu có được đồng bộ không?',
            answer: 'Có! Dữ liệu được lưu trên máy và đồng bộ lên Firebase khi bạn đăng nhập. Vào Cài đặt > Đồng bộ dữ liệu để đồng bộ thủ công.',
            isDark: isDark),
          _buildFAQCard(context: context, icon: Icons.notifications,
            question: 'Làm sao để bật nhắc nhở học tập?',
            answer: 'Vào Cài đặt > Thông báo học tập để cài đặt lịch nhắc nhở hàng ngày theo giờ bạn muốn.',
            isDark: isDark),
          _buildFAQCard(context: context, icon: Icons.volume_up,
            question: 'Làm sao để nghe phát âm từ vựng?',
            answer: 'Nhấn vào biểu tượng loa 🔊 bên cạnh từ vựng để nghe phát âm. Bạn có thể điều chỉnh tốc độ và giọng đọc trong Cài đặt > Âm thanh & phát âm.',
            isDark: isDark),
          _buildFAQCard(context: context, icon: Icons.password,
            question: 'Quên mật khẩu thì phải làm sao?',
            answer: 'Ở màn hình đăng nhập, nhấn "Quên mật khẩu?" và nhập email đã đăng ký. Link đặt lại mật khẩu sẽ được gửi đến email của bạn.',
            isDark: isDark),
          _buildFAQCard(context: context, icon: Icons.bar_chart,
            question: 'Xem tiến độ học tập ở đâu?',
            answer: 'Nhấn tab "Tiến độ" trên thanh điều hướng để xem biểu đồ XP, tiến độ từng chủ đề, và lịch sử luyện tập.',
            isDark: isDark),

          const SizedBox(height: AppConstants.paddingLarge),

          // Contact
          AppCard(
            child: Column(
              children: [
                Icon(
                  Icons.mail_outline,
                  size: 32,
                  color: context.primaryColor,
                ),
                const SizedBox(height: 8),
                Text(
                  'Vẫn cần trợ giúp?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Liên hệ: support@vocabapp.com',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.paddingLarge),

          // App version
          Center(
            child: Text(
              'Phiên bản 2.0.0',
              style: TextStyle(
                fontSize: 12,
                color: context.textTertiary,
              ),
            ),
          ),
          const SizedBox(height: AppConstants.paddingLarge),
        ],
      ),
    );
  }

  Widget _buildFAQCard({
    required BuildContext context,
    required IconData icon,
    required String question,
    required String answer,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Theme(
          data: ThemeData(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: context.primaryColor,
              ),
            ),
            title: Text(
              question,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
                color: context.textPrimary,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(72, 0, 16, 16),
                child: Text(
                  answer,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../db/database_helper.dart';
import '../../firebase/firebase_service.dart';
import '../../services/auth_service.dart';
import '../../models/topic.dart';
import '../../models/user.dart' as app_user;
import '../home_screen.dart';
import '../../services/settings_service.dart';
import '../../services/notification_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _dbHelper = DatabaseHelper.instance;
  final _firebaseService = FirebaseService();
  final _authService = AuthService();
  int _currentPage = 0;
  List<Topic> _allTopics = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    final topics = await _dbHelper.getTopics();
    if (mounted) setState(() => _allTopics = topics);
  }

  void _nextPage() {
    if (_currentPage < 4) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finishOnboarding() async {
    final provider = context.read<OnboardingProvider>();
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final firebaseUser = _authService.currentUser;
      if (firebaseUser == null) return;

      final userId = firebaseUser.uid;
      final topicsJson = jsonEncode(provider.selectedTopics);

      // ✅ Ensure local user record exists before updating
      var existingUser = await _dbHelper.getLocalUser(userId);
      if (existingUser == null) {
        // Create local user first
        await _dbHelper.upsertUser(
          id: userId,
          name: firebaseUser.displayName ?? 'User',
          email: firebaseUser.email ?? '',
          avatarUrl: firebaseUser.photoURL,
          lastLoginDate: DateTime.now(),
        );
      }

      // Save onboarding data to local DB
      await _dbHelper.updateOnboardingData(
        userId: userId,
        learningLevel: provider.learningLevel,
        selectedTopicsJson: topicsJson,
        dailyGoal: provider.dailyGoal,
      );

      // Sync to Firebase
      final userMap = await _dbHelper.getLocalUser(userId);
      if (userMap != null) {
        final user = app_user.User.fromMap(userMap);
        await _firebaseService.updateUser(user);
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      print('❌ Error saving onboarding: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            _buildProgressBar(),
            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _WelcomePage(onNext: _nextPage),
                  _SelectLevelPage(onNext: _nextPage, onBack: _prevPage),
                  _SelectTopicsPage(
                    topics: _allTopics,
                    onNext: _nextPage,
                    onBack: _prevPage,
                  ),
                  _SelectGoalPage(
                    onNext: _nextPage,
                    onBack: _prevPage,
                  ),
                  _SelectNotificationsPage(
                    onFinish: _finishOnboarding,
                    onBack: _prevPage,
                    isSaving: _isSaving,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Row(
        children: List.generate(5, (i) {
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: i <= _currentPage
                    ? const Color(0xFF6C63FF)
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ============================================
// PAGE 1: WELCOME
// ============================================
class _WelcomePage extends StatelessWidget {
  final VoidCallback onNext;
  const _WelcomePage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Lottie Animation instead of static logo
          Lottie.asset(
            'assets/lottie/onboarding_ai.json',
            height: 200,
            repeat: true,
          ),
          const SizedBox(height: 40),
          Text(
            'Chào mừng bạn đến với\nENG VOCA! 🎉',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Hãy cùng cá nhân hoá trải nghiệm học\nđể phù hợp nhất với bạn nhé!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),
          // Nút Bắt đầu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              child: const Text(
                'Bắt đầu 🚀',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// PAGE 2: SELECT LEVEL
// ============================================
class _SelectLevelPage extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  const _SelectLevelPage({required this.onNext, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<OnboardingProvider>();

    final levels = [
      _LevelOption(
        key: 'beginner',
        emoji: '🌱',
        title: 'Beginner',
        subtitle: 'Mới bắt đầu học tiếng Anh',
        color: const Color(0xFF4ADE80),
      ),
      _LevelOption(
        key: 'intermediate',
        emoji: '🌿',
        title: 'Intermediate',
        subtitle: 'Đã có nền tảng cơ bản',
        color: const Color(0xFF3B82F6),
      ),
      _LevelOption(
        key: 'advanced',
        emoji: '🌳',
        title: 'Advanced',
        subtitle: 'Nâng cao và chuyên sâu',
        color: const Color(0xFF8B5CF6),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            'Trình độ của bạn?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Chọn mức độ phù hợp để chúng tôi\ncá nhân hoá nội dung cho bạn',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 28),
          ...levels.map((level) {
            final isSelected = provider.learningLevel == level.key;
            return GestureDetector(
              onTap: () => provider.setLevel(level.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isSelected
                      ? level.color.withOpacity(0.1)
                      : (isDark ? const Color(0xFF2A2A3E) : Colors.white),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected ? level.color : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: level.color.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))]
                      : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
                ),
                child: Row(
                  children: [
                    Text(level.emoji, style: const TextStyle(fontSize: 32)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            level.title,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            level.subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: level.color, size: 28),
                  ],
                ),
              ),
            );
          }),
          const Spacer(),
          _buildNavButtons(
            context,
            onBack: onBack,
            onNext: provider.isLevelSelected ? onNext : null,
          ),
        ],
      ),
    );
  }
}

// ============================================
// PAGE 3: SELECT TOPICS
// ============================================
class _SelectTopicsPage extends StatelessWidget {
  final List<Topic> topics;
  final VoidCallback onNext;
  final VoidCallback onBack;
  const _SelectTopicsPage({
    required this.topics,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<OnboardingProvider>();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            'Chủ đề bạn quan tâm?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Chọn ít nhất 1 chủ đề (có thể chọn nhiều)',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: topics.length,
              itemBuilder: (ctx, i) {
                final topic = topics[i];
                final isSelected = provider.selectedTopics.contains(topic.id);
                return GestureDetector(
                  onTap: () => provider.toggleTopic(topic.id!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF4ADE80).withOpacity(0.1)
                          : (isDark ? const Color(0xFF2A2A3E) : Colors.white),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF4ADE80)
                            : (isDark ? Colors.grey.shade700 : Colors.grey.shade200),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF4ADE80).withOpacity(0.15)
                                : (isDark ? const Color(0xFF1E1E2E) : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              topic.iconName,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                topic.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                '${topic.totalWords} từ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey.shade500 : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Checkbox(
                          value: isSelected,
                          onChanged: (_) => provider.toggleTopic(topic.id!),
                          activeColor: const Color(0xFF4ADE80),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildNavButtons(
            context,
            onBack: onBack,
            onNext: provider.hasTopicsSelected ? onNext : null,
          ),
        ],
      ),
    );
  }
}

// ============================================
// PAGE 4: SELECT DAILY GOAL
// ============================================
class _SelectGoalPage extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  const _SelectGoalPage({
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<OnboardingProvider>();

    final goals = [
      _GoalOption(minutes: 10, emoji: '🎯', desc: 'Nhẹ nhàng, phù hợp người bận rộn'),
      _GoalOption(minutes: 15, emoji: '⚡', desc: 'Cân bằng, phổ biến nhất'),
      _GoalOption(minutes: 30, emoji: '🔥', desc: 'Tập trung, tiến bộ nhanh'),
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Lottie.asset(
              'assets/lottie/onboarding_trophy.json',
              height: 120,
              repeat: true,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Mục tiêu hàng ngày?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Chọn thời gian học mỗi ngày để duy trì streak',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 28),
          ...goals.map((goal) {
            final isSelected = provider.dailyGoal == goal.minutes;
            return GestureDetector(
              onTap: () => provider.setDailyGoal(goal.minutes),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)],
                        )
                      : null,
                  color: isSelected
                      ? null
                      : (isDark ? const Color(0xFF2A2A3E) : Colors.white),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: isSelected
                      ? [BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))]
                      : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
                ),
                child: Row(
                  children: [
                    Text(goal.emoji, style: const TextStyle(fontSize: 32)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${goal.minutes} phút / ngày',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            goal.desc,
                            style: TextStyle(
                              fontSize: 13,
                              color: isSelected
                                  ? Colors.white70
                                  : (isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle, color: Colors.white, size: 28),
                  ],
                ),
              ),
            );
          }),
          const Spacer(),
          // Next button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              child: const Text(
                'Tiếp tục →',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: onBack,
              child: Text(
                '← Quay lại',
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// PAGE 5: SELECT NOTIFICATIONS
// ============================================
class _SelectNotificationsPage extends StatefulWidget {
  final VoidCallback onFinish;
  final VoidCallback onBack;
  final bool isSaving;

  const _SelectNotificationsPage({
    required this.onFinish,
    required this.onBack,
    required this.isSaving,
  });

  @override
  State<_SelectNotificationsPage> createState() => _SelectNotificationsPageState();
}

class _SelectNotificationsPageState extends State<_SelectNotificationsPage> {
  final _settingsService = SettingsService.instance;
  final _notificationService = NotificationService.instance;

  bool _studyReminderEnabled = true;
  bool _reviewReminderEnabled = true;

  @override
  void initState() {
    super.initState();
    _studyReminderEnabled = _settingsService.getStudyReminderEnabled();
    _reviewReminderEnabled = _settingsService.getReviewReminderEnabled();
  }

  Future<void> _toggleStudy(bool value) async {
    setState(() => _studyReminderEnabled = value);
    await _settingsService.setStudyReminderEnabled(value);
    
    if (value) {
      final granted = await _notificationService.requestPermissions();
      if (granted) {
        await _notificationService.scheduleStudyReminder(
          _settingsService.getStudyReminderHour(),
          _settingsService.getStudyReminderMinute(),
        );
        await _settingsService.setNotificationsEnabled(true);
      } else {
        setState(() => _studyReminderEnabled = false);
        await _settingsService.setStudyReminderEnabled(false);
      }
    } else {
      await _notificationService.cancelStudyReminder();
    }
  }

  Future<void> _toggleReview(bool value) async {
    setState(() => _reviewReminderEnabled = value);
    await _settingsService.setReviewReminderEnabled(value);
    
    if (value) {
      final granted = await _notificationService.requestPermissions();
      if (granted) {
        await _notificationService.scheduleReviewReminder(
          hour: _settingsService.getReviewReminderHour(),
          minute: _settingsService.getReviewReminderMinute(),
        );
        await _settingsService.setNotificationsEnabled(true);
      } else {
        setState(() => _reviewReminderEnabled = false);
        await _settingsService.setReviewReminderEnabled(false);
      }
    } else {
      await _notificationService.cancelReviewReminder();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            'Nhắc nhở học tập 🔔',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Đừng để chuỗi học tập (streak) bị đứt quãng! Hãy bật thông báo để app nhắc bạn nhé.',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 32),
          
          // Study Reminder
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.menu_book, color: Color(0xFF6C63FF), size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nhắc học từ mới',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hàng ngày lúc 20:00',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _studyReminderEnabled,
                  onChanged: _toggleStudy,
                  activeColor: const Color(0xFF6C63FF),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),

          // Review Reminder
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.history, color: Color(0xFF9B59B6), size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nhắc ôn tập định kỳ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hàng ngày lúc 08:00',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _reviewReminderEnabled,
                  onChanged: _toggleReview,
                  activeColor: const Color(0xFF9B59B6),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Center(
            child: Text(
              '* Bạn có thể tùy chỉnh giờ giấc lúc khác trong phần Cài đặt của ứng dụng.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),

          const Spacer(),
          // Finish button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.isSaving ? null : widget.onFinish,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4ADE80),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              child: widget.isSaving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Hoàn thành ✨',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: widget.onBack,
              child: Text(
                '← Quay lại',
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// SHARED WIDGETS & DATA
// ============================================
Widget _buildNavButtons(
  BuildContext context, {
  required VoidCallback onBack,
  VoidCallback? onNext,
}) {
  return Row(
    children: [
      TextButton.icon(
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_ios, size: 16),
        label: const Text('Quay lại'),
        style: TextButton.styleFrom(
          foregroundColor: Colors.grey,
        ),
      ),
      const Spacer(),
      ElevatedButton(
        onPressed: onNext,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C63FF),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          'Tiếp tục →',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    ],
  );
}

class _LevelOption {
  final String key;
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  _LevelOption({
    required this.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}

class _GoalOption {
  final int minutes;
  final String emoji;
  final String desc;
  _GoalOption({required this.minutes, required this.emoji, required this.desc});
}

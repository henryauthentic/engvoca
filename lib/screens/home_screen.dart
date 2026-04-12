import 'package:flutter/material.dart';
import '../models/topic.dart';
import '../db/database_helper.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../utils/constants.dart';
import '../theme/theme_extensions.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/primary_button.dart';
import '../widgets/topic_card.dart';
import 'learning_mode_screen.dart';
import 'flashcard_screen.dart';
import 'quiz_screen.dart';
import 'review_screen.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';
import 'vocabulary_list_screen.dart';
import 'dictionary_screen.dart';
import 'daily_review_screen.dart';
import 'explore_words_screen.dart';
import 'practice_setup_screen.dart';
import 'ai_story_screen.dart';
import 'ai_chat_screen.dart';
import 'badges_screen.dart';
import '../utils/topic_icons.dart';
import '../widgets/duolingo_header.dart';
import '../models/user.dart';
import 'package:provider/provider.dart';
import '../providers/study_timer_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/common/animated_list_item.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _dbHelper = DatabaseHelper.instance;
  final _authService = AuthService();
  final _syncService = SyncService();
  int _selectedIndex = 0;
  List<Topic> _topics = [];
  bool _isLoading = true;
  User? _currentUser;
  
  // Dashboard Metrics
  int _dueWordsCount = 0;
  int _newWordsCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTopics();
    _loadUser();
    _autoSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final timerProvider = context.read<StudyTimerProvider>();
    if (state == AppLifecycleState.paused) {
      // App đi vào background → pause timer & save
      timerProvider.pauseTimer();
    } else if (state == AppLifecycleState.resumed) {
      // App quay lại → check daily reset
      timerProvider.checkDailyReset();
    }
  }

  Future<void> _loadUser() async {
    final firebaseUser = _authService.currentUser;
    if (firebaseUser != null) {
      var userMap = await _dbHelper.getLocalUser(firebaseUser.uid);
      
      // ✅ Nếu chưa có user local → tạo mới từ Firebase data
      if (userMap == null) {
        print('⚠️ Local user not found, creating from Firebase data');
        await _dbHelper.upsertUser(
          id: firebaseUser.uid,
          name: firebaseUser.displayName ?? 'User',
          email: firebaseUser.email ?? '',
          avatarUrl: firebaseUser.photoURL,
          lastLoginDate: DateTime.now(),
        );
        userMap = await _dbHelper.getLocalUser(firebaseUser.uid);
      }
      
      if (userMap != null && mounted) {
        setState(() {
          _currentUser = User.fromMap(userMap!);
        });
        print('👤 User loaded: streak=${_currentUser?.currentStreak}, xp=${_currentUser?.totalXp}, level=${_currentUser?.level}');
        
        // ✅ NEW: Initialize Study Timer
        if (_currentUser != null) {
          final timerProvider = context.read<StudyTimerProvider>();
          timerProvider.initialize(
            _currentUser!.id,
            _currentUser!.dailyGoal,
          );
          timerProvider.onGoalCompleted = () {
            if (mounted) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text('🎉 Xuất sắc!'),
                  content: const Text('Bạn đã hoàn thành mục tiêu học tập hôm nay!\nHãy tiếp tục duy trì nhé! 💪'),
                  actions: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4ADE80)),
                      child: const Text('Tuyệt vời!', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            }
          };
        }
      }
    }
  }

  Future<void> _loadTopics() async {
    setState(() => _isLoading = true);
    try {
      print('🔄 Loading topics...');
      
      await _dbHelper.updateTopicCounts();
      
      final topics = await _dbHelper.getTopics();
      
      // Fetch System Counts for Dashboard
      final dueWords = await _dbHelper.countDueWords(DateTime.now());
      final newWords = await _dbHelper.countNewWords();
      
      print('✅ Loaded ${topics.length} topics');
      
      for (var topic in topics) {
        final wordCount = await _dbHelper.countWordsByTopic(topic.id!);
        print('  📚 ${topic.name}:');
        print('     - Topic ID: "${topic.id}"');
        print('     - Words in DB: $wordCount');
        print('     - Displayed count: ${topic.wordCount}');
      }
      
      final sampleWords = await _dbHelper.getRandomWords(5);
      if (sampleWords.isNotEmpty) {
        print('\n📖 Sample words and their topic IDs:');
        for (var word in sampleWords) {
          print('   - ${word.word}: topicId="${word.topicId}"');
        }
      }
      
      setState(() {
        _topics = topics;
        _dueWordsCount = dueWords;
        _newWordsCount = newWords;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading topics: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải dữ liệu: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _autoSync() async {
    final user = _authService.currentUser;
    
    if (user == null) {
      print('⚠️ No user logged in, skipping auto sync');
      return;
    }

    try {
      print('🔄 Auto sync triggered for user: ${user.uid}');
      await _syncService.autoSync(user.uid);
      print('✅ Auto sync completed');
    } catch (e) {
      print('❌ Auto sync error: $e');
    }
  }

  Widget _buildHomeContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadUser();
        await _loadTopics();
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: DuolingoHeader(user: _currentUser),
          ),
          
          // ✅ NEW: Study Timer Widget
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverToBoxAdapter(
              child: _buildStudyTimerCard(isDark),
            ),
          ),
          
          SliverPadding(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            sliver: SliverToBoxAdapter(
              child: Card(
                color: context.cardColor,
                elevation: isDark ? 0 : 2,
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.paddingMedium),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Xin chào, ${_authService.currentUser?.displayName ?? "User"}!',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Hãy tiếp tục học tập mỗi ngày',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.emoji_events,
                          color: context.primaryColor,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chọn chế độ học',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingMedium),
                  
                  // 1. Review Mode (SM-2)
                  _buildModeCard(
                    title: 'Ôn tập hàng ngày (SM-2)',
                    subtitle: _dueWordsCount > 0 
                        ? '⚠️ $_dueWordsCount từ vựng đã đến hạn ôn tập' 
                        : '🎉 Bạn đã hoàn thành mục tiêu hôm nay!',
                    icon: Icons.history_edu,
                    color: Colors.orange.shade600,
                    buttonText: 'Ôn ngay',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DailyReviewScreen(),
                        ),
                      ).then((_) => _loadTopics());
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // 2. Learn New Words Mode
                  _buildModeCard(
                    title: 'Khám phá từ mới',
                    subtitle: '✨ Còn $_newWordsCount từ mới đang chờ bạn',
                    icon: Icons.auto_awesome,
                    color: Colors.green.shade600,
                    buttonText: 'Học mới',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ExploreWordsScreen(),
                        ),
                      ).then((_) => _loadTopics());
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // 3. Free Practice Mode
                  _buildModeCard(
                    title: 'Luyện tập tự do',
                    subtitle: 'Trắc nghiệm & điền từ với từ đã học',
                    icon: Icons.casino,
                    color: Colors.blue.shade600,
                    buttonText: 'Luyện tập',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PracticeSetupScreen(),
                        ),
                      ).then((_) => _loadTopics());
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // 4. AI Story Builder
                  _buildModeCard(
                    title: 'Sáng tác truyện bằng AI ✨',
                    subtitle: 'Ghi nhớ từ vựng qua câu chuyện thú vị',
                    icon: Icons.auto_stories,
                    color: const Color(0xFF6C63FF),
                    buttonText: 'Tạo truyện',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AiStoryScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // 5. AI Roleplay Chat
                  _buildModeCard(
                    title: 'Chat với AI 🤖',
                    subtitle: 'Luyện hội thoại tiếng Anh thực tế',
                    icon: Icons.chat_bubble_outline,
                    color: const Color(0xFF00B894),
                    buttonText: 'Bắt đầu chat',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AiChatScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // 6. Badges / Huy hiệu
                  _buildModeCard(
                    title: 'Huy hiệu 🏅',
                    subtitle: 'Xem bộ sưu tập thành tích của bạn',
                    icon: Icons.military_tech,
                    color: const Color(0xFFFFD700),
                    buttonText: 'Xem huy hiệu',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BadgesScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SliverPadding(padding: EdgeInsets.only(top: AppConstants.paddingLarge)),
          
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Chủ đề học tập',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
            ),
          ),
          
          const SliverPadding(padding: EdgeInsets.only(top: AppConstants.paddingMedium)),
          
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final topic = _topics[index];
                  return AnimatedListItem(
                    index: index,
                    child: TopicCard(
                      topic: topic,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => LearningModeScreen(topic: topic),
                          ),
                        );
                        _loadTopics();
                      },
                    ),
                  );
                },
                childCount: _topics.length,
              ),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AppCard(
      color: context.cardColor,
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PrimaryButton(
                onPressed: onTap,
                text: buttonText,
                backgroundColor: color,
                textColor: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ NEW: Study Timer Card
  Widget _buildStudyTimerCard(bool isDark) {
    return Consumer<StudyTimerProvider>(
      builder: (context, timer, _) {
        final isCompleted = timer.isCompleted;
        final goalMinutes = timer.dailyGoalSeconds ~/ 60;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: isCompleted
                ? const LinearGradient(colors: [Color(0xFF4ADE80), Color(0xFF22D3EE)])
                : const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (isCompleted ? const Color(0xFF4ADE80) : const Color(0xFF6C63FF))
                    .withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Circular Progress
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: timer.progress,
                      strokeWidth: 6,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                    Text(
                      isCompleted ? '✅' : timer.remainingFormatted,
                      style: TextStyle(
                        fontSize: isCompleted ? 24 : 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCompleted ? 'Hoàn thành! 🎉' : 'Mục tiêu hôm nay',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isCompleted
                          ? 'Bạn đã học $goalMinutes phút hôm nay'
                          : 'Đã học ${timer.elapsedFormatted} / $goalMinutes phút',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: timer.progress,
                        minHeight: 5,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Play/Pause button
              if (!isCompleted)
                GestureDetector(
                  onTap: () {
                    if (timer.isRunning) {
                      timer.pauseTimer();
                    } else {
                      timer.startTimer();
                    }
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      timer.isRunning ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 40,
              color: Colors.white,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTopicSelector(BuildContext context, String mode) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final topic = await showModalBottomSheet<Topic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              decoration: BoxDecoration(
                color: context.primaryColor.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(
                    mode == 'flashcard' ? Icons.style :
                    mode == 'quiz' ? Icons.quiz :
                    mode == 'learn_new' ? Icons.auto_awesome :
                    Icons.replay,
                    color: context.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    mode == 'flashcard' ? 'Chọn chủ đề để học Flashcard' :
                    mode == 'quiz' ? 'Chọn chủ đề Kiểm tra' :
                    mode == 'learn_new' ? 'Chọn chủ đề để Học từ mới' :
                    'Chọn chủ đề Ôn tập',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: context.textSecondary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                itemCount: _topics.length,
                itemBuilder: (context, index) {
                  final topic = _topics[index];
                  final isDisabled = mode == 'review' && topic.learnedCount == 0;
                  
                  return Card(
                    color: context.surfaceColor,
                    elevation: isDark ? 0 : 2,
                    margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
                    child: ListTile(
                      enabled: !isDisabled,
                      leading: Icon(
                        TopicIcons.get(topic.name),
                        size: 32,
                        color: isDisabled 
                            ? (isDark ? Colors.grey[700] : Colors.grey)
                            : (context.primaryColor),
                      ),
                      title: Text(
                        topic.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDisabled 
                              ? (isDark ? Colors.grey[700] : Colors.grey)
                              : (context.textPrimary),
                        ),
                      ),
                      subtitle: Text(
                        mode == 'review'
                            ? '${topic.learnedCount} từ đã học'
                            : '${topic.wordCount} từ',
                        style: TextStyle(
                          color: isDisabled 
                              ? (isDark ? Colors.grey[700] : Colors.grey)
                              : (context.textSecondary),
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        color: isDisabled 
                            ? (isDark ? Colors.grey[700] : Colors.grey)
                            : (context.primaryColor),
                      ),
                      onTap: isDisabled ? null : () => Navigator.pop(context, topic),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (topic != null && mounted) {
      Widget screen;
      if (mode == 'flashcard') {
        screen = FlashcardScreen(topic: topic);
      } else if (mode == 'quiz') {
        screen = QuizScreen(topic: topic);
      } else if (mode == 'learn_new') {
        screen = FlashcardScreen(topic: topic, isNewWordsMode: true);
      } else {
        screen = ReviewScreen(topic: topic);
      }
      
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => screen),
      );
      _loadTopics();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final screens = [
      _buildHomeContent(),
      const VocabularyListScreen(),
      const DictionaryScreen(),
      const ProgressScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: context.primaryColor,
        unselectedItemColor: context.textTertiary,
        backgroundColor: context.cardColor,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'Từ vựng',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Tra từ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: AppStrings.progress,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: AppStrings.settings,
          ),
        ],
      ),
    );
  }
}

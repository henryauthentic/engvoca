import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/topic.dart';
import '../db/database_helper.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/gamification_service.dart';
import '../firebase/firebase_service.dart';
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
import 'sub_topic_screen.dart';
import 'saved_words_screen.dart';
import 'content_update_screen.dart';
import '../utils/topic_icons.dart';
import '../widgets/duolingo_header.dart';
import '../models/user.dart';
import '../models/badge.dart';
import '../services/badge_service.dart';
import '../services/system_config_service.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/study_timer_provider.dart';
import '../models/content_update_info.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/common/animated_list_item.dart';
import '../widgets/common/skeleton_loader.dart';
import '../services/level_service.dart';

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
  String? _targetTopicId;
  List<Topic> _topics = [];
  bool _isLoading = true;
  User? _currentUser;
  
  // Dashboard Metrics
  int _dueWordsCount = 0;
  int _newWordsCount = 0;
  int _badgeUnlockedCount = 0;
  List<int> _weeklyStreak = List.filled(7, 0);

  // Daily Goal Progress (word-count based)
  int _reviewedTodayCount = 0;
  int _newLearnedTodayCount = 0;
  
  // Adaptive Learning
  int _difficultWordsCount = 0;
  double _memoryAccuracy = 1.0;

  // ✅ Smart Sync Banner
  bool _showSyncBanner = false;

  // ✅ Track active modal to avoid overlap
  bool _isShowingAnnouncement = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTopics();
    _loadUser();
    _loadBadgeStats();
    _loadWeeklyStreak();
    _loadDailyProgress();
    _smartSyncCheck();
    _checkSmartContentUpdate();
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
      // App quay lại → check daily reset & check updates ngầm
      timerProvider.checkDailyReset();
      _checkSmartContentUpdate();
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
        
        // ✅ Initialize Study Timer (background tracking for streak)
        if (_currentUser != null) {
          // Migration: old users with minute-based goals (10, 15) → word-based
          int dailyGoal = _currentUser!.dailyGoal;
          bool migrated = false;
          
          if (dailyGoal == 10) { dailyGoal = 15; migrated = true; }
          else if (dailyGoal == 15) { dailyGoal = 20; migrated = true; }
          // 20 and 30 stay as-is

          if (migrated) {
            // Update local DB
            await _dbHelper.upsertUser(
              id: _currentUser!.id,
              name: _currentUser!.displayName,
              email: _currentUser!.email,
              dailyGoal: dailyGoal,
            );
            // Update Firebase
            final updatedUser = _currentUser!.copyWith(dailyGoal: dailyGoal);
            await FirebaseService().updateUser(updatedUser);
            
            if (mounted) {
              setState(() {
                _currentUser = updatedUser;
              });
            }
          }

          final timerProvider = context.read<StudyTimerProvider>();
          timerProvider.initialize(
            _currentUser!.id,
            dailyGoal, // Still used for background time tracking
          );
          
          // ✅ Check if streak is broken (Login Check only)
          await GamificationService().updateStreak(null, false);
          
          // Reload user after streak check to update UI
          final refreshedUserMap = await _dbHelper.getLocalUser(_currentUser!.id);
          if (refreshedUserMap != null && mounted) {
            setState(() {
              _currentUser = User.fromMap(refreshedUserMap);
            });
          }
        }
      }
    }
  }

  Future<void> _loadDailyProgress() async {
    try {
      final reviewed = await _dbHelper.countReviewedToday();
      final newLearned = await _dbHelper.countNewLearnedToday();
      final difficultWords = await _dbHelper.getDifficultWords(limit: 1000);
      final accuracy = await _dbHelper.getGlobalMemoryAccuracy();
      
      if (mounted) {
        setState(() {
          _reviewedTodayCount = reviewed;
          _newLearnedTodayCount = newLearned;
          _difficultWordsCount = difficultWords.length;
          _memoryAccuracy = accuracy;
        });
      }
    } catch (e) {
      print('❌ Error loading daily progress: $e');
    }
  }

  Future<void> _loadTopics() async {
    setState(() => _isLoading = true);
    try {
      print('🔄 Loading topics...');
      
      await _dbHelper.updateTopicCounts();
      
      final topics = await _dbHelper.getParentTopics();
      
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

  /// ✅ Smart Sync: Check if Web has newer data (costs 1 Read only)
  /// Upload chỉ được kích hoạt khi user thực sự học/ôn xong (ở màn hình học).
  /// Ở đây chỉ DOWNLOAD khi cần, không upload lại.
  Future<void> _smartSyncCheck() async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      // ✅ One-time migration: full download for fresh installs / clear data
      final prefs = await SharedPreferences.getInstance();
      final migrated = prefs.getBool('sync_v5_migrated') ?? false;
      if (!migrated) {
        print('🔄 Sync v5 migration: full download for first-time setup...');
        await _syncService.downloadProgress(user.uid, deltaOnly: false);
        
        // Reload all local data after migration download
        await _loadUser();
        await _loadTopics();
        await _loadBadgeStats();
        await _loadWeeklyStreak();
        await _loadDailyProgress();
        
        await prefs.setBool('sync_v5_migrated', true);
        print('✅ Sync v5 migration complete');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Đã đồng bộ dữ liệu mới nhất!'),
              backgroundColor: Color(0xFF22C55E),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return; // Skip normal flow after migration
      }

      // 1. Check if server has newer data (costs 1 Firebase Read)
      final result = await _syncService.checkForWebChanges(user.uid);
      print('🔍 Smart sync: $result');
      
      if (result.needsSync && result.source == 'web') {
        // ✅ Web changes detected → Delta download only (no upload needed)
        print('📥 Web changes detected, downloading delta...');
        await _syncService.downloadProgress(user.uid, deltaOnly: true);
        
        // Reload local UI data
        await _loadUser();
        await _loadTopics();
        await _loadBadgeStats();
        await _loadWeeklyStreak();
        await _loadDailyProgress();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Đã đồng bộ dữ liệu từ Web!'),
              backgroundColor: Color(0xFF22C55E),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else if (result.needsSync) {
        // Non-web changes: show banner for user to decide
        setState(() => _showSyncBanner = true);
      }
      // ✅ Khi không có thay đổi → KHÔNG làm gì cả (tiết kiệm 100%)
    } catch (e) {
      print('❌ Smart sync check error: $e');
    }
  }

  /// ✅ Smart Content Sync: Content Delta Logic (Phase 4)
  Future<void> _checkSmartContentUpdate({bool force = false}) async {
    try {
      final updateInfo = await _syncService.checkContentUpdateNeeded(force: force);
      if (!updateInfo.hasUpdate || !mounted) return;

      switch (updateInfo.uxType) {
        case UpdateUXType.patch:
          // Silent sync in background
          print('🔄 Smart Content Sync: Patch update triggered silently');
          await _syncService.syncContentData(force: force);
          _loadTopics(); // Reload silently
          break;

        case UpdateUXType.minor:
          // Snackbar overlay
          print('🔄 Smart Content Sync: Minor update triggered');
          final snackbarController = ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                  SizedBox(width: 12),
                  Text('Đang cập nhật dữ liệu học tập...'),
                ],
              ),
              duration: const Duration(seconds: 10), // Keep it open while syncing
              backgroundColor: const Color(0xFF3B82F6),
            ),
          );

          await _syncService.syncContentData(force: force);
          _loadTopics(); // Reload data

          if (mounted) {
            snackbarController.close();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Dữ liệu học tập đã được cập nhật'),
                duration: Duration(seconds: 2),
                backgroundColor: Color(0xFF10B981), // Emerald Success
              ),
            );
          }
          break;

        case UpdateUXType.major:
          // Blocking UX
          print('🔄 Smart Content Sync: Major update triggered');
          final success = await Navigator.push<bool>(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => ContentUpdateScreen(updateInfo: updateInfo),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              fullscreenDialog: true,
            ),
          );

          if (success == true && mounted) {
            _loadTopics();
            _loadDailyProgress();
          }
          break;

        case UpdateUXType.none:
        default:
          break;
      }
    } catch (e) {
      print('❌ Smart content update check error: $e');
    }
  }

  /// ✅ Handle user tapping "Sync Now" on the banner
  Future<void> _performFullSync() async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      setState(() => _showSyncBanner = false);
      await _syncService.forceSync(user.uid);
      // Reload all local data after sync
      await _loadUser();
      await _loadTopics();
      await _loadBadgeStats();
      await _loadWeeklyStreak();
      await _loadDailyProgress();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đồng bộ thành công!'),
            backgroundColor: Color(0xFF22C55E),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Full sync error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi đồng bộ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadBadgeStats() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;
    try {
      final count = await BadgeService().getUnlockedCount(userId);
      if (mounted) setState(() => _badgeUnlockedCount = count);
    } catch (e) {
      print('❌ Error loading badge stats: $e');
    }
  }

  Future<void> _loadWeeklyStreak() async {
    try {
      final streak = await _dbHelper.getWeeklyStreak();
      if (mounted) setState(() => _weeklyStreak = streak);
    } catch (e) {
      print('❌ Error loading weekly streak: $e');
    }
  }

  // ═══════════════════════════════════════
  // HOME CONTENT — New Duolingo-style layout
  // ═══════════════════════════════════════

  Widget _buildHomeContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isLoading) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Skeleton
          Padding(
            padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 12),
            child: Row(
              children: [
                const SkeletonBox(width: 44, height: 44, borderRadius: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBox(width: 80, height: 12, borderRadius: 4),
                      SizedBox(height: 8),
                      SkeletonBox(width: 130, height: 18, borderRadius: 4),
                    ],
                  ),
                ),
                const SkeletonBox(width: 32, height: 32, borderRadius: 16),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: const [
                // 2. Stats Card Skeleton
                SkeletonBox(height: 90, borderRadius: 20),
                SizedBox(height: 12),
                // 3. Difficult Words Skeleton
                SkeletonBox(height: 64, borderRadius: 16),
                SizedBox(height: 12),
                // 4. Daily Goal Skeleton
                SkeletonBox(height: 220, borderRadius: 24),
                SizedBox(height: 12),
                // 5. Primary CTA Skeleton
                SkeletonBox(height: 64, borderRadius: 20),
                SizedBox(height: 24),
              ],
            ),
          ),
          
          // 6. Feature Grid Title Skeleton
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                SkeletonBox(width: 120, height: 24, borderRadius: 6),
                SkeletonBox(width: 60, height: 14, borderRadius: 4),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 7. Feature Grid Cards Skeleton
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: const [
                Expanded(child: SkeletonBox(height: 180, borderRadius: 20)),
                SizedBox(width: 12),
                Expanded(child: SkeletonBox(height: 180, borderRadius: 20)),
              ],
            ),
          ),
        ],
      ),
    );
  }

    return RefreshIndicator(
      onRefresh: () async {
        // ✅ Smart Sync: Only reload local data + check for Web changes
        await _loadUser();
        await _loadTopics();
        await _loadBadgeStats();
        await _loadWeeklyStreak();
        await _loadDailyProgress();
        await _smartSyncCheck();
        await _checkSmartContentUpdate(force: true);
      },
      child: CustomScrollView(
        slivers: [
          // 1. ✅ Smart Sync Banner
          if (_showSyncBanner)
            SliverToBoxAdapter(
              child: _buildSyncBanner(isDark),
            ),
          // 2. Header
          SliverToBoxAdapter(child: _buildHeader(isDark)),
          // 2. Stats Card
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            sliver: SliverToBoxAdapter(child: _buildStatsCard(isDark)),
          ),
          // 2.5 Difficult Words Card
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            sliver: SliverToBoxAdapter(child: _buildDifficultWordsCard(isDark)),
          ),
          // 3. Daily Goal
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: _buildDailyGoalCard()),
          ),
          // 4. Primary CTA
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverToBoxAdapter(child: _buildPrimaryCTA()),
          ),
          // 5. Feature Grid
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            sliver: SliverToBoxAdapter(child: _buildFeatureSection(isDark)),
          ),
          // 6. Streak Card
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(child: _buildStreakCard(isDark)),
          ),
          // 7. Topic List
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Text('Chủ đề học tập', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary)),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(top: 12)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final topic = _topics[index];
                return AnimatedListItem(
                  index: index,
                  child: TopicCard(
                    topic: topic,
                    onTap: () {
                      setState(() {
                        _selectedIndex = 1;
                        _targetTopicId = topic.id;
                      });
                    },
                  ),
                );
              }, childCount: _topics.length),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }

  // ═══ HEADER ═══
  Widget _buildHeader(bool isDark) {
    final name = _currentUser?.displayName ?? _authService.currentUser?.displayName ?? 'User';
    final avatarUrl = _currentUser?.avatar;
    final isNetworkAvatar = avatarUrl != null && avatarUrl.startsWith('http');

    return Padding(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: context.primaryColor.withOpacity(0.2),
            backgroundImage: isNetworkAvatar ? NetworkImage(avatarUrl) : null,
            child: isNetworkAvatar ? null : Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: TextStyle(fontWeight: FontWeight.bold, color: context.primaryColor, fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Xin chào,', style: TextStyle(fontSize: 13, color: context.textSecondary)),
                Text('$name 👋', style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary, fontSize: 18)),
              ],
            ),
          ),
          
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: context.textSecondary),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  // ═══ SMART SYNC BANNER ═══
  Widget _buildSyncBanner(bool isDark) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1E3A5F), const Color(0xFF0D2137)]
                : [const Color(0xFFE0F2FE), const Color(0xFFBAE6FD)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF3B82F6).withOpacity(0.3) : const Color(0xFF3B82F6).withOpacity(0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B82F6).withOpacity(isDark ? 0.15 : 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Center(child: Text('⚡', style: TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dữ liệu mới từ Web',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E40AF),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Bạn vừa học trên Web. Đồng bộ ngay?',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : const Color(0xFF1E40AF).withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => setState(() => _showSyncBanner = false),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
              ),
              child: Text(
                'Để sau',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            ElevatedButton(
              onPressed: _performFullSync,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
                minimumSize: Size.zero,
              ),
              child: const Text('Đồng bộ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(bool isDark) {
    String levelDisplay = 'A1';
    if (_currentUser != null) {
      final score = LevelService.calculateEffectiveScore(_currentUser!.learnedWords, _memoryAccuracy);
      levelDisplay = LevelService.getLevelId(score).toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? context.surfaceColor : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('🔥', '${_currentUser?.currentStreak ?? 0}', 'Ngày streak'),
          Container(width: 1, height: 40, color: context.dividerColor),
          _buildStatItem('⭐', '${_currentUser?.totalXp ?? 0}', 'XP'),
          Container(width: 1, height: 40, color: context.dividerColor),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BadgesScreen())).then((_) => _loadBadgeStats()),
            child: _buildStatItem('🏆', '$_badgeUnlockedCount', 'Huy hiệu'),
          ),
          Container(width: 1, height: 40, color: context.dividerColor),
          _buildStatItem('🎓', levelDisplay, 'Cấp độ'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: context.textSecondary, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ═══ DIFFICULT WORDS CARD ═══
  Widget _buildDifficultWordsCard(bool isDark) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedWordsScreen()))
            .then((_) { _loadDailyProgress(); }); // reload after returning
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF3F2113) : const Color(0xFFFFF2E8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? const Color(0xFF8C3E14) : const Color(0xFFFFD8C2), width: 1),
          boxShadow: isDark ? null : [BoxShadow(color: Colors.orange.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: Colors.orange.shade100.withOpacity(isDark ? 0.2 : 1), shape: BoxShape.circle),
              child: const Center(child: Text('🔥', style: TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Từ khó của bạn',
                        style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold,
                          color: isDark ? Colors.orange.shade300 : Colors.deepOrange.shade700,
                        ),
                      ),
                      if (_difficultWordsCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange.shade600,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$_difficultWordsCount',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Xem & ôn lại các từ bạn hay sai',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.orange.shade100.withOpacity(0.7) : Colors.deepOrange.shade900.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: isDark ? Colors.orange.shade300 : Colors.deepOrange.shade400),
          ],
        ),
      ),
    );
  }

  // ═══ DAILY GOAL CARD (Word-count based) ═══
  Widget _buildDailyGoalCard() {
    // Goal data
    int dailyGoalWords = _currentUser?.dailyGoal ?? 15;
    // Migration: old minute-based values
    if (dailyGoalWords == 10) dailyGoalWords = 15;
    else if (dailyGoalWords == 15) dailyGoalWords = 20;

    final reviewGoal = _dueWordsCount; // SM-2 driven, bắt buộc
    final newGoal = dailyGoalWords;    // User-set goal
    final reviewDone = _reviewedTodayCount.clamp(0, reviewGoal > 0 ? reviewGoal : 1);
    final newDone = _newLearnedTodayCount;

    final reviewProgress = reviewGoal > 0 ? (reviewDone / reviewGoal).clamp(0.0, 1.0) : 0.0;
    final newProgress = newGoal > 0 ? (newDone / newGoal).clamp(0.0, 1.0) : 0.0;
    final reviewComplete = reviewGoal == 0 || reviewDone >= reviewGoal;
    final newComplete = newDone >= newGoal;
    final allComplete = reviewComplete && newComplete;

    // Overall percentage for motivation bar
    final totalGoal = reviewGoal + newGoal;
    final totalDone = reviewDone + newDone;
    final overallPercent = totalGoal > 0 ? ((totalDone / totalGoal) * 100).round().clamp(0, 100) : 0;

    // Motivation text
    String motivationText;
    String motivationEmoji;
    if (allComplete) {
      motivationText = 'Xuất sắc! Bạn đã hoàn thành tất cả!';
      motivationEmoji = '🎉';
    } else if (reviewComplete && !newComplete) {
      motivationText = 'Đã xong ôn tập! Học thêm từ mới nào!';
      motivationEmoji = '🚀';
    } else if (overallPercent >= 50) {
      motivationText = 'Bạn đang làm rất tốt!';
      motivationEmoji = '🔥';
    } else if (overallPercent > 0) {
      motivationText = 'Tiếp tục phát huy nhé!';
      motivationEmoji = '💪';
    } else {
      motivationText = 'Bắt đầu nào!';
      motivationEmoji = '✨';
    }

    // CTA
    String ctaText;
    VoidCallback ctaAction;
    if (_dueWordsCount > 0 && !reviewComplete) {
      ctaText = 'Ôn tập ngay';
      ctaAction = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyReviewScreen())).then((_) { _loadUser(); _loadTopics(); _loadDailyProgress(); _loadWeeklyStreak(); });
    } else if (!newComplete) {
      ctaText = 'Học từ mới';
      ctaAction = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExploreWordsScreen())).then((_) { _loadUser(); _loadTopics(); _loadDailyProgress(); _loadWeeklyStreak(); });
    } else {
      ctaText = 'Khám phá thêm';
      ctaAction = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExploreWordsScreen())).then((_) { _loadUser(); _loadTopics(); _loadDailyProgress(); _loadWeeklyStreak(); });
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: allComplete
            ? const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF4ADE80), Color(0xFF22D3EE)])
            : const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFFEDE9FE), Color(0xFFDBEAFE)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 16, offset: const Offset(0, 6),
        )],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(children: [
            Text('🎯', style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text('Mục tiêu hôm nay',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                color: allComplete ? Colors.white : const Color(0xFF1E293B))),
          ]),
          const SizedBox(height: 18),

          // Ôn tập row
          _buildGoalRow(
            icon: '🔥',
            label: 'Ôn tập',
            subtitle: 'SM-2 Spaced Repetition',
            done: reviewDone,
            total: reviewGoal,
            progress: reviewProgress,
            progressColor: const Color(0xFFF97316),
            bgColor: const Color(0xFFFFEDD5),
            isComplete: reviewComplete,
            isDark: allComplete,
          ),
          const SizedBox(height: 14),

          // Từ mới row
          _buildGoalRow(
            icon: '✨',
            label: 'Từ mới',
            subtitle: 'Học từ mới mỗi ngày',
            done: newDone,
            total: newGoal,
            progress: newProgress,
            progressColor: const Color(0xFF22C55E),
            bgColor: const Color(0xFFDCFCE7),
            isComplete: newComplete,
            isDark: allComplete,
          ),
          const SizedBox(height: 16),

          // Motivation bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: allComplete ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: allComplete ? Colors.white.withOpacity(0.3) : const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Text('$overallPercent%',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                    color: allComplete ? Colors.white : const Color(0xFF6366F1)))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$motivationText $motivationEmoji',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: allComplete ? Colors.white : const Color(0xFF1E293B))),
                  if (!allComplete)
                    Text('Tiếp tục phát huy nhé!',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              )),
            ]),
          ),
          const SizedBox(height: 14),

          // CTA Button
          SizedBox(width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: ctaAction,
              icon: Icon(allComplete ? Icons.explore : Icons.play_circle_filled, size: 20),
              label: Text(ctaText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: allComplete ? Colors.white : const Color(0xFF6366F1),
                foregroundColor: allComplete ? const Color(0xFF22C55E) : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalRow({
    required String icon,
    required String label,
    required String subtitle,
    required int done,
    required int total,
    required double progress,
    required Color progressColor,
    required Color bgColor,
    required bool isComplete,
    required bool isDark,
  }) {
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark ? Colors.white70 : Colors.grey.shade500;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.15) : bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
              const Spacer(),
              if (isComplete && total > 0)
                Text('Hoàn thành ✔', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF22C55E)))
              else
                RichText(text: TextSpan(children: [
                  TextSpan(text: '$done', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: progressColor)),
                  TextSpan(text: ' / $total từ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: subtitleColor)),
                ])),
            ]),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 11, color: subtitleColor)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: isDark ? Colors.white.withOpacity(0.15) : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(progressColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${(progress * 100).round()}%',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: subtitleColor)),
            ]),
          ],
        )),
      ],
    );
  }

  // ═══ PRIMARY CTA ═══
  Widget _buildPrimaryCTA() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = 1;
          _targetTopicId = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft, end: Alignment.centerRight,
            colors: [Color(0xFF86EFAC), Color(0xFF4ADE80)] // Lighter to darker green
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: const Color(0xFF4ADE80).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          // Simulated 3D Rocket with an emoji
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: const Text('🚀', style: TextStyle(fontSize: 32)),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Học ngay', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF064E3B))), // Dark green text
            const SizedBox(height: 4),
            Text('Bắt đầu học và chinh phục\nmục tiêu của bạn!', style: TextStyle(fontSize: 13, color: const Color(0xFF064E3B).withOpacity(0.8), height: 1.3)),
          ])),
          Container(width: 48, height: 48, decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
            child: const Icon(Icons.arrow_forward, color: Colors.white, size: 24)),
        ]),
      ),
    );
  }

  // ═══ FEATURE GRID ═══
  Widget _buildFeatureSection(bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Khám phá', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary)),
        const Spacer(),
        GestureDetector(
          onTap: () {},
          child: Row(children: [
            Text('Xem thêm', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.primaryColor)),
            Icon(Icons.chevron_right, color: context.primaryColor, size: 20),
          ]),
        ),
      ]),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.1,
        children: [
          _buildFeatureCard('📅', 'Ôn tập hàng ngày', 'Củng cố từ vựng đã học', const Color(0xFFF97316), isDark,
            chipEmoji: '🎉', chipText: 'SM-2', chipColor: const Color(0xFFFFEDD5), chipTextColor: const Color(0xFFC2410C),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyReviewScreen())).then((_) { _loadUser(); _loadTopics(); _loadWeeklyStreak(); })),
          _buildFeatureCard('🌱', 'Khám phá từ mới', 'Học từ mới mỗi ngày', const Color(0xFF22C55E), isDark,
            chipEmoji: '✅', chipText: 'Còn $_newWordsCount từ mới', chipColor: const Color(0xFFDCFCE7), chipTextColor: const Color(0xFF15803D),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExploreWordsScreen())).then((_) { _loadUser(); _loadTopics(); _loadWeeklyStreak(); })),
          _buildFeatureCard('🏋️', 'Luyện tập tự do', 'Trắc nghiệm & điền từ', const Color(0xFF3B82F6), isDark,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PracticeSetupScreen())).then((_) { _loadUser(); _loadTopics(); _loadWeeklyStreak(); })),
          _buildFeatureCard('🤖', 'Chat AI', 'Luyện hội thoại tiếng Anh', const Color(0xFF8B5CF6), isDark,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen()))),
        ],
      ),
    ]);
  }

  Widget _buildFeatureCard(String emoji, String title, String sub, Color color, bool isDark, {
    String? chipEmoji, String? chipText, Color? chipColor, Color? chipTextColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? context.surfaceColor : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.textPrimary)),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(fontSize: 11, color: context.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (chipText != null && chipColor != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: chipColor, borderRadius: BorderRadius.circular(12)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (chipEmoji != null) ...[Text(chipEmoji, style: const TextStyle(fontSize: 10)), const SizedBox(width: 4)],
                    Text(chipText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: chipTextColor)),
                  ]),
                )
              else
                const Spacer(),
              if (chipText != null) const Spacer(),
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: const Icon(Icons.chevron_right, color: Colors.white, size: 18),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  // ═══ STREAK CARD ═══
  Widget _buildStreakCard(bool isDark) {
    final now = DateTime.now();
    
    final currentStreak = _currentUser?.currentStreak ?? 0;
    final longestStreak = _currentUser?.longestStreak ?? 0;
    final isBroken = currentStreak == 0 && longestStreak > 0;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? context.surfaceColor : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBroken ? '💀 Streak đã reset!' : '🔥 Streak $currentStreak ngày', 
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.bold, 
                    color: isBroken ? Colors.redAccent : context.textPrimary
                  )
                ),
                if (isBroken)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Kỷ lục: $longestStreak ngày. Xây dựng lại nào!',
                      style: TextStyle(fontSize: 12, color: Colors.redAccent.withOpacity(0.8)),
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: Row(children: [
              Text('Giữ vững chuỗi nhé!', style: TextStyle(fontSize: 13, color: context.textSecondary)),
              Icon(Icons.chevron_right, color: context.textSecondary, size: 18),
            ]),
          ),
        ]),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(7, (i) {
          final state = _weeklyStreak.length > i ? _weeklyStreak[i] : 0; // 0: future/today unstudied, 1: studied, 2: grace, 3: missed
          final date = now.subtract(Duration(days: 5 - i));
          final daysOfWeek = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
          final dayStr = daysOfWeek[date.weekday % 7];
          final isToday = i == 5;

          Widget circleContent;
          if (state == 1) {
            circleContent = const Text('🔥', style: TextStyle(fontSize: 20));
          } else if (state == 2) {
            circleContent = const Text('😴', style: TextStyle(fontSize: 20));
          } else if (state == 3) {
            // Missed past day -> grey fire
            circleContent = const Text('🔥', style: TextStyle(fontSize: 20));
          } else {
            // Future or today not yet studied
            circleContent = const SizedBox.shrink();
          }

          Color circleColor;
          if (state == 1) {
            circleColor = const Color(0xFFFF6B35); // Orange
          } else if (state == 2) {
            circleColor = const Color(0xFF6C63FF); // Purple
          } else if (state == 3) {
            // Grey outline, transparent bg for missed day
            circleColor = Colors.transparent;
          } else {
            circleColor = isDark ? Colors.grey.shade800 : const Color(0xFFF1F5F9);
          }

          return Column(children: [
            ColorFiltered(
              colorFilter: state == 3 
                  ? const ColorFilter.matrix([
                      0.33, 0.33, 0.33, 0, 0,
                      0.33, 0.33, 0.33, 0, 0,
                      0.33, 0.33, 0.33, 0, 0,
                      0, 0, 0, 0.5, 0, // opacity 0.5
                    ])
                  : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: state == 3 ? (isDark ? Colors.grey.shade900 : Colors.grey.shade200) : circleColor,
                  border: isToday && state == 0 ? Border.all(color: const Color(0xFFFF6B35), width: 2) : 
                          state == 3 ? Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300, width: 1) : null,
                ),
                child: Center(child: circleContent),
              ),
            ),
            const SizedBox(height: 8),
            Text(dayStr, style: TextStyle(
              fontSize: 12, 
              color: (isToday) ? const Color(0xFFFF6B35) : context.textSecondary, 
              fontWeight: (isToday) ? FontWeight.bold : FontWeight.w500
            )),
          ]);
        })),
      ]),
    );
  }


  Future<void> _showTopicSelector(BuildContext context, String mode) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Topic? selectedParent;
    List<Topic> displayTopics = _topics;
    bool isModalLoading = false;

    final topic = await showModalBottomSheet<Topic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
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
                      if (selectedParent != null)
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: context.primaryColor),
                          onPressed: () {
                            setModalState(() {
                              selectedParent = null;
                              displayTopics = _topics;
                            });
                          },
                        )
                      else
                        Icon(
                          mode == 'flashcard' ? Icons.style :
                          mode == 'quiz' ? Icons.quiz :
                          mode == 'learn_new' ? Icons.auto_awesome :
                          Icons.replay,
                          color: context.primaryColor,
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          selectedParent != null ? selectedParent!.name :
                          mode == 'flashcard' ? 'Chọn chủ đề để học Flashcard' :
                          mode == 'quiz' ? 'Chọn chủ đề Kiểm tra' :
                          mode == 'learn_new' ? 'Chọn chủ đề để Học từ mới' :
                          'Chọn chủ đề Ôn tập',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: context.textSecondary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: isModalLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          padding: const EdgeInsets.all(AppConstants.paddingMedium),
                          itemCount: displayTopics.length,
                          itemBuilder: (context, index) {
                            final topicItem = displayTopics[index];
                            final isDisabled = mode == 'review' && topicItem.learnedCount == 0 && topicItem.wordCount > 0;
                            
                            return Card(
                              color: context.surfaceColor,
                              elevation: isDark ? 0 : 2,
                              margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
                              child: ListTile(
                                enabled: !isDisabled,
                                leading: Icon(
                                  TopicIcons.get(topicItem.name),
                                  size: 32,
                                  color: isDisabled ? (isDark ? Colors.grey[700] : Colors.grey) : context.primaryColor,
                                ),
                                title: Text(
                                  topicItem.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDisabled ? (isDark ? Colors.grey[700] : Colors.grey) : context.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  mode == 'review'
                                      ? '${topicItem.learnedCount} từ đã học'
                                      : '${topicItem.wordCount} từ',
                                  style: TextStyle(
                                    color: isDisabled ? (isDark ? Colors.grey[700] : Colors.grey) : context.textSecondary,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.arrow_forward_ios,
                                  color: isDisabled ? (isDark ? Colors.grey[700] : Colors.grey) : context.primaryColor,
                                  size: 16,
                                ),
                                onTap: isDisabled ? null : () async {
                                  if (selectedParent == null) {
                                    setModalState(() => isModalLoading = true);
                                    final hasChildren = await _dbHelper.hasChildren(topicItem.id!);
                                    if (hasChildren) {
                                      final children = await _dbHelper.getChildTopics(topicItem.id!);
                                      setModalState(() {
                                        selectedParent = topicItem;
                                        displayTopics = children;
                                        isModalLoading = false;
                                      });
                                    } else {
                                      Navigator.pop(context, topicItem);
                                    }
                                  } else {
                                    // Already in child level
                                    Navigator.pop(context, topicItem);
                                  }
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
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
      _loadUser();
      _loadTopics();
    }
  }

  // ── Announcement Helpers ──

  Color _parseHex(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  static const _templatePresets = {
    'info':        {'icon': Icons.info_outline_rounded,      'g': ['#3b82f6', '#6366f1']},
    'warning':     {'icon': Icons.warning_amber_rounded,     'g': ['#f59e0b', '#ef4444']},
    'success':     {'icon': Icons.check_circle_outline,      'g': ['#10b981', '#34d399']},
    'reward':      {'icon': Icons.card_giftcard,             'g': ['#f6d365', '#fda085']},
    'streak':      {'icon': Icons.local_fire_department,     'g': ['#f83600', '#f9d423']},
    'update':      {'icon': Icons.system_update_alt,         'g': ['#11998e', '#38ef7d']},
    'event':       {'icon': Icons.celebration,               'g': ['#6a11cb', '#2575fc']},
    'promotion':   {'icon': Icons.campaign,                  'g': ['#ec4899', '#8b5cf6']},
    'achievement': {'icon': Icons.emoji_events,              'g': ['#667eea', '#764ba2']},
  };

  List<Color> _getGradientColors(Map<String, dynamic> ann, bool isDark) {
    // Priority: custom gradient > template preset > fallback
    final gradKey = isDark ? 'darkBgGradient' : 'bgGradient';
    final custom = ann[gradKey] as List?;
    if (custom != null && custom.length == 2 && custom[0].toString().isNotEmpty && custom[1].toString().isNotEmpty) {
      return [_parseHex(custom[0].toString()), _parseHex(custom[1].toString())];
    }
    // Fallback to bgGradient even in dark mode
    final bg = ann['bgGradient'] as List?;
    if (bg != null && bg.length == 2 && bg[0].toString().isNotEmpty && bg[1].toString().isNotEmpty) {
      final colors = [_parseHex(bg[0].toString()), _parseHex(bg[1].toString())];
      return isDark ? colors.map((c) => Color.lerp(c, Colors.black, 0.5)!).toList() : colors;
    }
    // Template preset
    final template = ann['template'] ?? ann['type'] ?? 'info';
    final preset = _templatePresets[template] ?? _templatePresets['info']!;
    final g = preset['g'] as List<String>;
    final colors = [_parseHex(g[0]), _parseHex(g[1])];
    return isDark ? colors.map((c) => Color.lerp(c, Colors.black, 0.4)!).toList() : colors;
  }

  IconData _getTemplateIcon(Map<String, dynamic> ann) {
    final template = ann['template'] ?? ann['type'] ?? 'info';
    final preset = _templatePresets[template] ?? _templatePresets['info']!;
    return preset['icon'] as IconData;
  }

  Widget _buildCtaButton(Map<String, dynamic> ann, List<Color> gradientColors, SystemConfigService config, {BuildContext? modalContext}) {
    final ctaText = ann['ctaText'] as String? ?? 'Xem chi tiết';
    final ctaStyle = ann['ctaStyle'] ?? 'primary';
    final hasDeepLink = ann['deepLink'] != null && ann['deepLink'].toString().isNotEmpty;
    if (!hasDeepLink && ann['ctaText'] == null) return const SizedBox.shrink();

    void onTap() async {
      if (modalContext != null) {
        Navigator.of(modalContext).pop();
      }
      config.dismissAnnouncement(ann['id'] ?? '');

      if (hasDeepLink) {
        final link = ann['deepLink'].toString();
        if (link.startsWith('http')) {
          final url = Uri.parse(link);
          try {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          } catch (e) {
            debugPrint('Could not launch $url: $e');
          }
        } else if (link.startsWith('tab:')) {
          final tab = link.split(':')[1];
          int targetIndex = 0;
          if (tab == 'vocabulary') targetIndex = 1;
          else if (tab == 'dictionary') targetIndex = 2;
          else if (tab == 'progress') targetIndex = 3;
          else if (tab == 'settings') targetIndex = 4;
          
          setState(() {
            _selectedIndex = targetIndex;
          });
        }
      }
    }

    if (ctaStyle == 'ghost') {
      return GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(ctaText, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, decoration: TextDecoration.underline, decorationColor: Colors.white70)),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: ctaStyle == 'primary' ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: ctaStyle == 'secondary' ? Border.all(color: Colors.white54) : null,
        ),
        child: Text(ctaText, style: TextStyle(
          color: ctaStyle == 'primary' ? gradientColors[0] : Colors.white,
          fontSize: 12, fontWeight: FontWeight.bold,
        )),
      ),
    );
  }

  /// ✅ Build Announcement Banner (inline on Home)
  Widget _buildAnnouncementBanner(Map<String, dynamic> ann, bool isDark, SystemConfigService config, {bool isFirst = false}) {
    final gradientColors = _getGradientColors(ann, isDark);
    final iconData = _getTemplateIcon(ann);
    final isDismissible = ann['isDismissible'] ?? true;
    final badge = ann['badge'] as String?;
    final subtitle = ann['subtitle'] as String?;
    final illustrationUrl = ann['illustrationUrl'] as String?;
    final imageSize = ann['imageSize'] ?? 'small';
    final topPad = isFirst ? MediaQuery.of(context).padding.top + 4 : 8.0;

    return Container(
      margin: EdgeInsets.fromLTRB(16, topPad, 16, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: gradientColors[0].withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: Icon(iconData, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (badge != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(10)),
                          child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      Text(ann['title'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                      ],
                      const SizedBox(height: 4),
                      Text(ann['message'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, height: 1.4)),
                      _buildCtaButton(ann, gradientColors, config),
                    ],
                  ),
                ),
                if (illustrationUrl != null && illustrationUrl.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(illustrationUrl, width: 64, height: 64, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  ),
                ],
              ],
            ),
          ),
          if (isDismissible)
            Positioned(
              top: 6, right: 6,
              child: GestureDetector(
                onTap: () => config.dismissAnnouncement(ann['id'] ?? ''),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white70, size: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// ✅ Show Announcement as Fullscreen Popup
  Future<void> _showAnnouncementPopup(Map<String, dynamic> ann, bool isDark, SystemConfigService config) async {
    config.dismissAnnouncement(ann['id'] ?? '');
    final gradientColors = _getGradientColors(ann, isDark);
    final iconData = _getTemplateIcon(ann);
    final isDismissible = ann['isDismissible'] ?? true;
    final badge = ann['badge'] as String?;
    final subtitle = ann['subtitle'] as String?;
    final illustrationUrl = ann['illustrationUrl'] as String?;

    await showGeneralDialog(
      context: context,
      barrierDismissible: isDismissible,
      barrierLabel: 'announcement',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (ctx, a1, a2, child) => FadeTransition(
        opacity: a1,
        child: ScaleTransition(scale: CurvedAnimation(parent: a1, curve: Curves.easeOutBack), child: child),
      ),
      pageBuilder: (ctx, _, __) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: gradientColors[0].withOpacity(0.5), blurRadius: 40, offset: const Offset(0, 16))],
          ),
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                children: [
                  // Decorative circles
                  Positioned(top: -40, right: -40, child: Container(width: 140, height: 140, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)))),
                  Positioned(bottom: -30, left: -30, child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.06)))),
                  // Content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (illustrationUrl != null && illustrationUrl.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.network(illustrationUrl, width: 140, height: 140, fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                                  child: Icon(iconData, color: Colors.white, size: 52),
                                )),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                              child: Icon(iconData, color: Colors.white, size: 52),
                            ),
                          ),
                        if (badge != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                            child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                        Text(ann['title'] ?? '', textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 6),
                          Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 15)),
                        ],
                        const SizedBox(height: 14),
                        Text(ann['message'] ?? '', textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15, height: 1.6)),
                        const SizedBox(height: 20),
                        // Full-width CTA
                        if (ann['deepLink'] != null || ann['ctaText'] != null)
                          SizedBox(
                            width: double.infinity,
                            child: _buildCtaButton(ann, gradientColors, config, modalContext: ctx),
                          ),
                        if (isDismissible) ...[
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: () => Navigator.of(ctx).pop(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                              child: const Text('Đóng', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ✅ Show Announcement as Bottom Sheet (Premium)
  Future<void> _showAnnouncementBottomSheet(Map<String, dynamic> ann, bool isDark, SystemConfigService config) async {
    config.dismissAnnouncement(ann['id'] ?? '');
    final gradientColors = _getGradientColors(ann, isDark);
    final iconData = _getTemplateIcon(ann);
    final isDismissible = ann['isDismissible'] ?? true;
    final badge = ann['badge'] as String?;
    final subtitle = ann['subtitle'] as String?;
    final illustrationUrl = ann['illustrationUrl'] as String?;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.65),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors, begin: Alignment.topCenter, end: Alignment.bottomCenter),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [BoxShadow(color: gradientColors[0].withOpacity(0.3), blurRadius: 20, offset: const Offset(0, -8))],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(top: -30, right: -20, child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.06)))),
              Positioned(bottom: -20, left: -20, child: Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)))),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle bar
                      Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(3))),
                      const SizedBox(height: 20),
                      // Illustration on top if available
                      if (illustrationUrl != null && illustrationUrl.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(illustrationUrl, width: double.infinity, height: 120, fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
                                child: Icon(iconData, color: Colors.white, size: 40),
                              )),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
                            child: Icon(iconData, color: Colors.white, size: 40),
                          ),
                        ),
                      if (badge != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
                          child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      Text(ann['title'] ?? '', textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14)),
                      ],
                      const SizedBox(height: 12),
                      Text(ann['message'] ?? '', textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15, height: 1.6)),
                      const SizedBox(height: 20),
                      // Full-width CTA
                      if (ann['deepLink'] != null || ann['ctaText'] != null)
                        SizedBox(width: double.infinity, child: _buildCtaButton(ann, gradientColors, config, modalContext: ctx)),
                      if (isDismissible) ...[
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: () => Navigator.of(ctx).pop(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                            child: const Text('Đóng', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final screens = [
      _buildHomeContent(),
      VocabularyListScreen(scrollToTopicId: _targetTopicId),
      const DictionaryScreen(),
      const ProgressScreen(),
      const SettingsScreen(),
    ];

    String currentTabName = 'home';
    if (_selectedIndex == 1) currentTabName = 'vocabulary';
    else if (_selectedIndex == 2) currentTabName = 'dictionary';
    else if (_selectedIndex == 3) currentTabName = 'progress';
    else if (_selectedIndex == 4) currentTabName = 'settings';

    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: Consumer<SystemConfigService>(
        builder: (context, config, child) {
          final banners = <Map<String, dynamic>>[];
          
          if (config.activeAnnouncements.isNotEmpty) {
            for (final ann in config.activeAnnouncements) {
              final mode = ann['displayMode'] ?? 'banner';
              if (mode == 'popup' || mode == 'bottom_sheet') {
                final targetScreens = List<String>.from(ann['targetScreens'] ?? []);
                // If it targets specific screens and current screen is not one of them, skip it for now.
                if (targetScreens.isNotEmpty && !targetScreens.contains(currentTabName)) {
                  continue;
                }
                
                if (!config.isDismissedThisSession(ann['id'] ?? '')) {
                  if (!_isShowingAnnouncement) {
                    _isShowingAnnouncement = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      if (!mounted) return;
                      if (config.isDismissedThisSession(ann['id'] ?? '')) {
                        _isShowingAnnouncement = false;
                        return;
                      }
                      if (mode == 'popup') {
                        await _showAnnouncementPopup(ann, isDark, config);
                      } else {
                        await _showAnnouncementBottomSheet(ann, isDark, config);
                      }
                      
                      _isShowingAnnouncement = false;
                      if (mounted) setState(() {}); // Trigger next modal if any
                    });
                  }
                }
              } else {
                final targetScreens = List<String>.from(ann['targetScreens'] ?? ['home']);
                if (targetScreens.contains(currentTabName) || targetScreens.isEmpty) {
                  banners.add(ann);
                }
              }
            }
          }

          if (banners.isEmpty) {
            return screens[_selectedIndex];
          }

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: banners.asMap().entries.map((e) => _buildAnnouncementBanner(e.value, isDark, config, isFirst: e.key == 0)).toList(),
                  ),
                ),
              ),
            ],
            body: screens[_selectedIndex],
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index == 0) {
            // Khi quay lại tab Home, load lại dữ liệu để cập nhật XP/Streak
            _loadUser();
            _loadDailyProgress();
            _loadWeeklyStreak();
            _loadTopics();
          }
          setState(() {
            _selectedIndex = index;
            if (index != 1) _targetTopicId = null; // clear target if navigating away, or let it clear when user manually taps tab 1
            if (index == 1) _targetTopicId = null; 
          });
        },
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

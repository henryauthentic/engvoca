import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/chat_message.dart';
import '../services/ai_service.dart';
import '../services/badge_service.dart';
import '../db/database_helper.dart';
import '../theme/theme_extensions.dart';
import '../utils/constants.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  String? _selectedScenario;
  final List<ChatMessage> _messages = [];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isTyping = false;

  static const scenarios = [
    {'id': 'restaurant', 'name': 'Gọi đồ ăn', 'emoji': '🍕', 'desc': 'Đặt món tại nhà hàng'},
    {'id': 'job_interview', 'name': 'Phỏng vấn', 'emoji': '💼', 'desc': 'Trả lời câu hỏi tuyển dụng'},
    {'id': 'hotel', 'name': 'Đặt phòng', 'emoji': '🏨', 'desc': 'Check-in / check-out'},
    {'id': 'shopping', 'name': 'Mua sắm', 'emoji': '🛒', 'desc': 'Hỏi giá, mặc cả'},
    {'id': 'airport', 'name': 'Sân bay', 'emoji': '✈️', 'desc': 'Check-in, hỏi cổng bay'},
    {'id': 'doctor', 'name': 'Khám bệnh', 'emoji': '🏥', 'desc': 'Mô tả triệu chứng'},
    {'id': 'free_chat', 'name': 'Tự do', 'emoji': '💬', 'desc': 'Nói bất cứ gì bạn muốn'},
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _selectScenario(String scenarioId) {
    setState(() {
      _selectedScenario = scenarioId;
      _messages.clear();
    });
    _sendInitialGreeting();
  }

  Future<void> _sendInitialGreeting() async {
    setState(() => _isTyping = true);

    try {
      final response = await AiService().chat(
        messageHistory: [
          {'role': 'user', 'content': 'Hi!'},
        ],
        scenario: _selectedScenario!,
      );

      setState(() {
        _messages.add(ChatMessage(role: 'assistant', content: response));
        _isTyping = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isTyping = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isTyping) return;

    _inputController.clear();

    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      // Build history for API
      final history = _messages.map((m) => {
        'role': m.role,
        'content': m.content,
      }).toList();

      final response = await AiService().chat(
        messageHistory: history,
        scenario: _selectedScenario!,
      );

      setState(() {
        _messages.add(ChatMessage(role: 'assistant', content: response));
        _isTyping = false;
      });
      _scrollToBottom();

      // Track chat count for badges
      _trackChatForBadge();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content: 'Xin lỗi, có lỗi xảy ra. Vui lòng thử lại!',
        ));
        _isTyping = false;
      });
    }
  }

  Future<void> _trackChatForBadge() async {
    final userId = DatabaseHelper.instance.currentUserId;
    if (userId == null) return;

    // Count this as a chat message; every 5 messages = 1 "conversation"
    final userMsgCount = _messages.where((m) => m.role == 'user').length;
    if (userMsgCount % 5 == 0) {
      final count = await DatabaseHelper.instance.incrementCounter(userId, 'chat_count');
      final newBadges = await BadgeService().checkChatBadge(userId, count);
      if (newBadges.isNotEmpty && mounted) {
        _showBadgeUnlocked(newBadges.first);
      }
    }
  }

  void _showBadgeUnlocked(dynamic badge) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🏅 Huy hiệu mới: ${badge.name} ${badge.icon}'),
        backgroundColor: const Color(0xFFFFD700),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _resetChat() {
    setState(() {
      _selectedScenario = null;
      _messages.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedScenario != null
            ? _getScenarioName(_selectedScenario!)
            : 'Chat với AI 💬'),
        actions: [
          if (_selectedScenario != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetChat,
              tooltip: 'Cuộc hội thoại mới',
            ),
        ],
      ),
      body: _selectedScenario == null
          ? _buildScenarioSelector()
          : _buildChatView(),
    );
  }

  // ============================================
  // SCENARIO SELECTOR
  // ============================================
  Widget _buildScenarioSelector() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppConstants.paddingLarge),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF4834DF)],
              ),
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            ),
            child: const Column(
              children: [
                Text('🤖', style: TextStyle(fontSize: 48)),
                SizedBox(height: 8),
                Text(
                  'Luyện hội thoại tiếng Anh',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Chọn tình huống để bắt đầu.\nAI sẽ tự động sửa lỗi ngữ pháp cho bạn!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),

          const SizedBox(height: 24),

          Text(
            'Chọn tình huống',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),

          const SizedBox(height: 16),

          // Scenario cards
          ...scenarios.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildScenarioCard(s, i),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildScenarioCard(Map<String, String> scenario, int index) {
    final colors = [
      [const Color(0xFFFF6B6B), const Color(0xFFEE5A24)],
      [const Color(0xFF6C63FF), const Color(0xFF4834DF)],
      [const Color(0xFF00B894), const Color(0xFF00897B)],
      [const Color(0xFFFF9FF3), const Color(0xFFF368E0)],
      [const Color(0xFF54A0FF), const Color(0xFF2E86DE)],
      [const Color(0xFFFF6348), const Color(0xFFEB4D4B)],
      [const Color(0xFF5F27CD), const Color(0xFF341F97)],
    ];
    final gradientColors = colors[index % colors.length];

    return GestureDetector(
      onTap: () => _selectScenario(scenario['id']!),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors.map((c) => c).toList()),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(scenario['emoji']!, style: const TextStyle(fontSize: 36)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scenario['name']!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    scenario['desc']!,
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 18),
          ],
        ),
      ),
    ).animate(delay: (index * 80).ms)
     .fadeIn(duration: 300.ms)
     .slideX(begin: 0.3);
  }

  // ============================================
  // CHAT VIEW
  // ============================================
  Widget _buildChatView() {
    return Column(
      children: [
        // Messages
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            itemCount: _messages.length + (_isTyping ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _messages.length && _isTyping) {
                return _buildTypingIndicator();
              }
              return _buildMessageBubble(_messages[index], index);
            },
          ),
        ),

        // Input bar
        _buildInputBar(),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage message, int index) {
    final isUser = message.role == 'user';

    // Split correction from response
    String mainContent = message.content;
    String? correction;
    if (!isUser && message.content.contains('💡 Correction:')) {
      final parts = message.content.split('💡 Correction:');
      mainContent = parts[0].trim();
      correction = parts[1].trim();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Main bubble
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isUser
                  ? context.primaryColor
                  : context.cardColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isUser ? 18 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 18),
              ),
              border: isUser
                  ? null
                  : Border.all(color: context.dividerColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              mainContent,
              style: TextStyle(
                fontSize: 15,
                color: isUser ? Colors.white : context.textPrimary,
                height: 1.4,
              ),
            ),
          ),

          // Grammar correction box
          if (correction != null) ...[
            const SizedBox(height: 6),
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD).withOpacity(context.isDark ? 0.15 : 1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFD700).withOpacity(0.4),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      correction,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.isDark
                            ? const Color(0xFFFFD700)
                            : const Color(0xFF856404),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.1);
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.dividerColor),
            ),
            child: Lottie.asset('assets/lottie/chat_typing.json', height: 40, width: 60),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: context.textTertiary,
        shape: BoxShape.circle,
      ),
    ).animate(
      onPlay: (c) => c.repeat(),
    ).fadeIn(
      delay: (index * 200).ms,
      duration: 400.ms,
    ).then().fadeOut(duration: 400.ms);
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: context.cardColor,
        border: Border(
          top: BorderSide(color: context.dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              decoration: InputDecoration(
                hintText: 'Nhập tin nhắn bằng tiếng Anh...',
                hintStyle: TextStyle(color: context.textTertiary, fontSize: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: context.subtleBackground,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              maxLines: null,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: context.primaryColor,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _isTyping ? null : _sendMessage,
              icon: Icon(
                Icons.send,
                color: _isTyping ? Colors.white54 : Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getScenarioName(String id) {
    final s = scenarios.firstWhere((s) => s['id'] == id, orElse: () => scenarios.last);
    return '${s['emoji']} ${s['name']}';
  }
}

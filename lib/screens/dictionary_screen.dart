import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/dictionary_entry.dart';
import '../services/dictionary_service.dart';
import '../utils/constants.dart';
import '../theme/theme_extensions.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/animated_list_item.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../services/ai_service.dart';
import '../models/word.dart';
import '../db/database_helper.dart';
import '../models/topic.dart';
import 'flashcard_screen.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final _searchController = TextEditingController();
  final _dictionaryService = DictionaryService();
  final FlutterTts _flutterTts = FlutterTts();
  
  List<DictionaryEntry> _entries = [];
  bool _isLoading = false;
  String? _errorMessage;
  List<String> _searchHistory = [];
  bool _isMeaningsExpanded = true;
  bool _isSaved = false;
  String? _savedWordId;
  
  // AI Service
  final AiService _aiService = AiService();
  
  // Speech to Text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _lastRecognizedWords = '';

  @override
  void initState() {
    super.initState();
    _initTts();
    _initSpeech();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  Future<void> _searchWord(String word) async {
    if (word.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _entries = [];
    });

    try {
      final entries = await _dictionaryService.searchWord(word);
      setState(() {
        _entries = entries;
        _isLoading = false;
        if (!_searchHistory.contains(word)) {
          _searchHistory.insert(0, word);
          if (_searchHistory.length > 10) {
            _searchHistory.removeLast();
          }
        }
      });
      if (entries.isNotEmpty) {
        await _checkIfSaved(entries.first.word);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _initSpeech() async {
    try {
      bool available = await _speech.initialize(
        onStatus: (status) => print('STT Status: $status'),
        onError: (errorNotification) => print('STT Error: $errorNotification'),
      );
      if (!available) {
        print("Speech recognition not available on this device.");
      }
    } catch (e) {
      print('STT Init Error: $e');
    }
  }

  void _startListening() async {
    // Check permission first
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cần cấp quyền Micro để sử dụng tính năng này')),
        );
        return;
      }
    }

    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            setState(() {
              _lastRecognizedWords = result.recognizedWords;
              if (result.finalResult) {
                _searchController.text = _lastRecognizedWords;
                _isListening = false;
                _searchWord(_lastRecognizedWords);
              }
            });
          },
          localeId: 'en_US', // Listen in English
        );
      }
    }
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _checkIfSaved(String wordText) async {
    final db = await DatabaseHelper.instance.database;
    // Tìm từ trong DB (có thể chữ hoa/thường)
    final words = await db.query('words', where: 'LOWER(word) = ?', whereArgs: [wordText.toLowerCase()]);
    if (words.isNotEmpty) {
      final wId = words.first['id'] as String;
      _savedWordId = wId;
      final progress = await db.query('user_word_progress', where: 'word_id = ? AND is_difficult = 1', whereArgs: [wId]);
      setState(() {
        _isSaved = progress.isNotEmpty;
      });
    } else {
      _savedWordId = null;
      setState(() {
        _isSaved = false;
      });
    }
  }

  Future<void> _toggleSaveWord(DictionaryEntry entry) async {
    final db = await DatabaseHelper.instance.database;
    String wordIdToToggle = _savedWordId ?? entry.word; // Dùng từ làm ID nếu chưa có

    if (_savedWordId == null) {
      // Từ này chưa có trong database, tạo mới và đưa vào "Từ vựng yêu thích"
      try {
        final newWord = Word(
          id: wordIdToToggle,
          word: entry.word,
          pronunciation: entry.phonetic ?? '',
          meaning: entry.meanings.isNotEmpty && entry.meanings.first.definitions.isNotEmpty 
              ? (entry.meanings.first.definitions.first.definitionVi ?? entry.meanings.first.definitions.first.definition)
              : 'Không có nghĩa',
          example: entry.meanings.isNotEmpty && entry.meanings.first.definitions.isNotEmpty && entry.meanings.first.definitions.first.example != null
              ? entry.meanings.first.definitions.first.example!
              : '',
          topicId: 'dictionary_saved', // Dummy topic
          isLearned: false,
          difficultyLevel: 1,
          createdAt: DateTime.now().toIso8601String(),
        );

        final wordMap = {
          'id': newWord.id,
          'word': newWord.word,
          'pronunciation': newWord.pronunciation,
          'meaning': newWord.meaning,
          'example': newWord.example,
          DatabaseHelper.instance.topicIdColumn: newWord.topicId,
          'is_favorite': 0,
          'is_learned': 1,
          'difficulty_level': newWord.difficultyLevel,
          'created_at': newWord.createdAt,
        };
        await db.insert('words', wordMap);
        _savedWordId = wordIdToToggle;
      } catch (e) {
        print('Lỗi tạo từ mới: $e');
      }
    }

    // Đảo trạng thái trong progress
    await DatabaseHelper.instance.toggleDifficult(wordIdToToggle);
    setState(() {
      _isSaved = !_isSaved;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isSaved ? 'Đã lưu từ' : 'Đã bỏ lưu'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _isSaved ? Colors.orange : Colors.grey.shade800,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showAiAction(DictionaryEntry entry, bool isSentencePractice) {
    // Convert DictionaryEntry to a mock Word to reuse Flashcard's AI widgets
    final mockWord = Word(
      id: entry.word,
      topicId: 'dictionary',
      word: entry.word,
      meaning: entry.meanings.isNotEmpty && entry.meanings.first.definitions.isNotEmpty 
          ? (entry.meanings.first.definitions.first.definitionVi ?? entry.meanings.first.definitions.first.definition)
          : 'Không có nghĩa',
      pronunciation: entry.phonetic ?? '',
      pos: entry.meanings.isNotEmpty ? entry.meanings.first.partOfSpeech : 'unknown',
      example: entry.meanings.isNotEmpty && entry.meanings.first.definitions.isNotEmpty && entry.meanings.first.definitions.first.example != null
          ? entry.meanings.first.definitions.first.example!
          : '',
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (isSentencePractice) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => AiSentencePracticeSheet(
          word: mockWord,
          aiService: _aiService,
          isDark: isDark,
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => AiBottomSheet(
          word: mockWord,
          aiService: _aiService,
          isDark: isDark,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF8B5CF6); // Purple
    final backgroundColor = isDark ? context.backgroundColor : const Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── CUSTOM HEADER ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: isDark ? [] : [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))
                        ],
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text('Tra cứu từ điển', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                        Text('Học từ vựng mỗi ngày ✨', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.volume_up_rounded, size: 20, color: primaryColor),
                  ),
                ],
              ),
            ),

            // ── SEARCH BAR ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(isDark ? 0.2 : 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: primaryColor.withOpacity(0.2), width: 1.5),
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Nhập từ tiếng Anh...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                    prefixIcon: Icon(Icons.search, color: primaryColor),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: Colors.grey.shade400, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _entries = [];
                                _errorMessage = null;
                              });
                            },
                          ),
                        GestureDetector(
                          onTap: _isListening ? _stopListening : _startListening,
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _isListening ? Colors.red.withOpacity(0.15) : primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isListening ? Icons.mic_off_rounded : Icons.mic_rounded,
                              color: _isListening ? Colors.red : primaryColor,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onSubmitted: _searchWord,
                  textInputAction: TextInputAction.search,
                ),
              ),
            ),

            // ── RECENT SEARCHES (Chips) ──
            if (_searchHistory.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text('Tìm kiếm gần đây', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _searchHistory.clear()),
                      child: Text('Xóa tất cả', style: TextStyle(fontSize: 12, color: primaryColor, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            if (_searchHistory.isNotEmpty)
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _searchHistory.length,
                  itemBuilder: (context, index) {
                    final word = _searchHistory[index];
                    return GestureDetector(
                      onTap: () {
                        _searchController.text = word;
                        _searchWord(word);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(isDark ? 0.15 : 0.08),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          word,
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Content
            Expanded(
              child: _buildContent(isDark),
            ),

            // ── AI ASSISTANT BANNER PINNED AT BOTTOM ──
            if (_entries.isNotEmpty && !_isLoading && _errorMessage == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF8B5CF6), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Trợ lý AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                            Text('Hiểu sâu hơn về từ này', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildAiActionBtn(Icons.auto_awesome, 'Giải thích', () => _showAiAction(_entries.first, false)),
                      const SizedBox(width: 6),
                      _buildAiActionBtn(Icons.edit_note_rounded, 'Đặt câu', () => _showAiAction(_entries.first, true)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: context.primaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Đang tìm kiếm...',
              style: TextStyle(
                fontSize: 16,
                color: context.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppConstants.errorColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search_off,
                  size: 64,
                  color: AppConstants.errorColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _searchWord(_searchController.text),
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_entries.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Illustration
            Lottie.asset(
              'assets/lottie/empty_box.json',
              width: 140,
              height: 140,
            ),
            const SizedBox(height: 16),
            Text(
              'Tra cứu từ điển tiếng Anh',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nhập từ bạn muốn tra và nhấn tìm kiếm\nđể xem giải nghĩa chi tiết',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Word of the day
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  const Text('🔥 ', style: TextStyle(fontSize: 18)),
                  Text(
                    'Word of the day',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF8B5CF6).withOpacity(0.1), const Color(0xFF3B82F6).withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('serendipity', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6))),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('C2', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('/ˌser.ənˈdɪp.ə.ti/', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                  const SizedBox(height: 12),
                  const Text('Sự tình cờ may mắn, khả năng tìm được những điều thú vị một cách ngẫu nhiên.', style: TextStyle(fontSize: 15, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _searchController.text = 'serendipity';
                      _searchWord('serendipity');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(double.infinity, 44),
                      elevation: 0,
                    ),
                    child: const Text('Tra cứu từ này', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        return AnimatedListItem(
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
            child: _buildEntryCard(_entries[index], isDark),
          ),
        );
      },
    );
  }

  Widget _buildEntryCard(DictionaryEntry entry, bool isDark) {
    return Column(
      children: [
        // ── HERO CARD ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withOpacity(isDark ? 0.2 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            gradient: isDark ? null : const LinearGradient(
              colors: [Color(0xFFFDFBFB), Color(0xFFEBEDEE)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              entry.word,
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () => _toggleSaveWord(entry),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _isSaved ? Colors.orange.withOpacity(0.15) : const Color(0xFF8B5CF6).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isSaved ? Icons.star_rounded : Icons.star_border_rounded, 
                                  size: 24, 
                                  color: _isSaved ? Colors.orange : const Color(0xFF8B5CF6)
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (entry.phonetic != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                entry.phonetic!,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade500,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _speak(entry.word),
                                child: Icon(Icons.volume_up_rounded, size: 18, color: const Color(0xFF8B5CF6)),
                              ),
                            ],
                          ),
                        ]
                      ],
                    ),
                  ),
                  if (entry.phonetics.any((p) => p.audio?.isNotEmpty == true) || true)
                    Column(
                      children: [
                        GestureDetector(
                          onTap: () => _speak(entry.word),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8B5CF6).withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 28),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6, height: 6,
                                decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 4),
                              const Text('A1', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              
              if (entry.meanings.isNotEmpty && entry.meanings[0].definitions.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Divider(height: 1, thickness: 1),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.meanings[0].partOfSpeech,
                    style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 12, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  entry.meanings[0].definitions[0].definition,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                    height: 1.4,
                  ),
                ),
                if (entry.meanings[0].definitions[0].definitionVi != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    entry.meanings[0].definitions[0].definitionVi!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF8B5CF6),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                // Nút "Học ngay"
                ElevatedButton.icon(
                  onPressed: () {
                    final mockWord = Word(
                      id: entry.word,
                      topicId: 'dictionary',
                      word: entry.word,
                      meaning: entry.meanings.isNotEmpty && entry.meanings[0].definitions.isNotEmpty 
                          ? (entry.meanings[0].definitions[0].definitionVi ?? entry.meanings[0].definitions[0].definition)
                          : 'Không có nghĩa',
                      pronunciation: entry.phonetic ?? '',
                      pos: entry.meanings.isNotEmpty ? entry.meanings[0].partOfSpeech : 'unknown',
                      example: entry.meanings.isNotEmpty && entry.meanings[0].definitions.isNotEmpty && entry.meanings[0].definitions[0].example != null
                          ? entry.meanings[0].definitions[0].example!
                          : '',
                    );
                    final dummyTopic = Topic(id: 'dictionary', name: 'Từ điển', description: 'Từ tra cứu', orderIndex: 0);
                    
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FlashcardScreen(
                          topic: dummyTopic,
                          preloadedWords: [mockWord],
                          isNewWordsMode: true,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.flash_on_rounded, size: 20),
                  label: const Text('Học ngay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    minimumSize: const Size(double.infinity, 50),
                    elevation: 0,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── MEANINGS LIST ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isMeaningsExpanded = !_isMeaningsExpanded;
                  });
                },
                child: Row(
                  children: [
                    Icon(Icons.menu_book_rounded, color: Colors.grey.shade500, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Nghĩa của từ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const Spacer(),
                    Text(_isMeaningsExpanded ? 'Thu gọn' : 'Xem thêm', style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 13)),
                    Icon(_isMeaningsExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: const Color(0xFF8B5CF6), size: 18),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Always show first definition
              if (entry.meanings.isNotEmpty)
                _buildMeaningSection(entry.meanings.first, 0, isDark, maxDefs: _isMeaningsExpanded ? null : 1),
              // Show remaining meanings only when expanded
              if (_isMeaningsExpanded && entry.meanings.length > 1) ...[
                ...entry.meanings.sublist(1).asMap().entries.map((meaningEntry) {
                  return _buildMeaningSection(meaningEntry.value, meaningEntry.key + 1, isDark);
                }).toList(),
              ],
              // Show "Xem thêm nghĩa khác" button when collapsed and there's more content
              if (!_isMeaningsExpanded && _hasMoreDefinitions(entry))
                GestureDetector(
                  onTap: () => setState(() => _isMeaningsExpanded = true),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Xem thêm nghĩa khác', style: TextStyle(color: const Color(0xFF8B5CF6), fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF8B5CF6), size: 18),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── EXAMPLES (If any) ──
        if (_hasExamples(entry)) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.format_quote_rounded, color: Colors.amber, size: 24),
                    const SizedBox(width: 8),
                    const Text('Ví dụ', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16)),
                    const Spacer(),
                    Icon(Icons.bookmark_rounded, color: Colors.amber.shade600, size: 20),
                  ],
                ),
                const SizedBox(height: 12),
                ..._buildExampleItems(entry, isDark),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // ── RELATED WORDS ──
        if (_hasSynonyms(entry)) ...[
          Row(
            children: [
              Icon(Icons.link_rounded, color: const Color(0xFF8B5CF6).withOpacity(0.7), size: 20),
              const SizedBox(width: 8),
              const Text('Từ liên quan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6))),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _getAllSynonyms(entry).take(10).map((syn) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(syn, style: const TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.w500)),
            )).toList(),
          ),
          const SizedBox(height: 24),
        ],

      ],
    );
  }

  Widget _buildAiActionBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasExamples(DictionaryEntry entry) {
    for (var meaning in entry.meanings) {
      if (meaning.definitions.any((d) => d.example != null && d.example!.isNotEmpty)) return true;
    }
    return false;
  }

  List<Widget> _buildExampleItems(DictionaryEntry entry, bool isDark) {
    List<Widget> examples = [];
    for (var meaning in entry.meanings) {
      for (var def in meaning.definitions) {
        if (def.example != null && def.example!.isNotEmpty) {
          examples.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    def.example!,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ví dụ minh họa (chưa dịch)',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    }
    return examples.take(3).toList();
  }

  bool _hasSynonyms(DictionaryEntry entry) {
    return entry.meanings.any((m) => m.synonyms.isNotEmpty);
  }

  List<String> _getAllSynonyms(DictionaryEntry entry) {
    Set<String> syns = {};
    for (var meaning in entry.meanings) {
      syns.addAll(meaning.synonyms);
    }
    return syns.toList();
  }

  bool _hasMoreDefinitions(DictionaryEntry entry) {
    if (entry.meanings.length > 1) return true;
    if (entry.meanings.isNotEmpty && entry.meanings.first.definitions.length > 1) return true;
    return false;
  }

  Widget _buildMeaningSection(Meaning meaning, int index, bool isDark, {int? maxDefs}) {
    final defs = maxDefs != null ? meaning.definitions.take(maxDefs).toList() : meaning.definitions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...defs.asMap().entries.map((defEntry) {
          return _buildDefinitionItem(defEntry.value, defEntry.key + 1, isDark);
        }).toList(),
      ],
    );
  }

  Widget _buildDefinitionItem(Definition definition, int number, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  definition.definition,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF334155),
                  ),
                ),
                if (definition.definitionVi != null && definition.definitionVi!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    definition.definitionVi!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF8B5CF6),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _speak(definition.definition),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.volume_up_rounded, size: 16, color: Color(0xFF8B5CF6)),
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/dictionary_entry.dart';
import '../services/dictionary_service.dart';
import '../utils/constants.dart';
import '../theme/theme_extensions.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/animated_list_item.dart';

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

  @override
  void initState() {
    super.initState();
    _initTts();
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
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: const Text('Tra cứu từ điển'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  context.primaryColor,
                  context.primaryColor.withOpacity(0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: context.primaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        color: context.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Nhập từ tiếng Anh...',
                        hintStyle: TextStyle(
                          color: context.textTertiary,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: context.primaryColor,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: context.textSecondary,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _entries = [];
                                    _errorMessage = null;
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: context.surfaceColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      onSubmitted: _searchWord,
                      textInputAction: TextInputAction.search,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    onTap: () => _searchWord(_searchController.text),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      child: Icon(
                        Icons.search,
                        color: context.primaryColor,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _buildContent(isDark),
          ),
        ],
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
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Lottie.asset(
              'assets/lottie/empty_box.json',
              width: 150,
              height: 150,
            ),
            const SizedBox(height: 24),
            Text(
              'Tra cứu từ điển tiếng Anh',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Nhập từ bạn muốn tra và nhấn tìm kiếm\nhoặc chọn từ lịch sử bên dưới',
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchHistory.isNotEmpty) ...[
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.history,
                          color: context.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Lịch sử tìm kiếm',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _searchHistory.map((word) {
                        return Material(
                          color: context.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              _searchController.text = word;
                              _searchWord(word);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: context.primaryColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    word,
                                    style: TextStyle(
                                      color: context.primaryColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
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
    return AppCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          gradient: isDark 
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Colors.grey.shade50,
                  ],
                ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Word header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      context.primaryColor.withOpacity(0.1),
                      context.primaryColor.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.word,
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: context.primaryColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (entry.phonetic != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: context.surfaceColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: context.primaryColor.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                entry.phonetic!,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: context.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (entry.phonetics.any((p) => p.audio?.isNotEmpty == true))
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              context.primaryColor,
                              context.primaryColor.withOpacity(0.8),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: context.primaryColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(100),
                            onTap: () => _speak(entry.word),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              child: const Icon(
                                Icons.volume_up,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Origin
              if (entry.origin != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark 
                          ? [
                              Colors.blue.shade900.withOpacity(0.3),
                              Colors.blue.shade900.withOpacity(0.1),
                            ]
                          : [
                              Colors.blue.shade50,
                              Colors.blue.shade100.withOpacity(0.3),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    border: Border.all(
                      color: isDark ? Colors.blue.shade700 : Colors.blue.shade200,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark 
                              ? Colors.blue.shade900.withOpacity(0.5)
                              : Colors.blue.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.auto_stories,
                          color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nguồn gốc',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.origin!,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.blue.shade100 : Colors.blue.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Meanings
              ...entry.meanings.asMap().entries.map((meaningEntry) {
                final meaningIndex = meaningEntry.key;
                final meaning = meaningEntry.value;
                return _buildMeaningSection(meaning, meaningIndex, isDark);
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMeaningSection(Meaning meaning, int index, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (index > 0) 
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Divider(
              thickness: 1,
              color: isDark ? context.subtleBackground : Colors.grey.shade300,
            ),
          ),
        
        // Part of speech
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                context.primaryColor,
                context.primaryColor.withOpacity(0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: context.primaryColor.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            meaning.partOfSpeech,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Definitions
        ...meaning.definitions.asMap().entries.map((defEntry) {
          final defIndex = defEntry.key;
          final definition = defEntry.value;
          return _buildDefinitionItem(definition, defIndex + 1, isDark);
        }).toList(),
        
        // Synonyms
        if (meaning.synonyms.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildWordList(
            'Từ đồng nghĩa',
            meaning.synonyms,
            isDark ? Colors.green.shade400 : Colors.green,
            Icons.check_circle_outline,
            isDark,
          ),
        ],
        
        // Antonyms
        if (meaning.antonyms.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildWordList(
            'Từ trái nghĩa',
            meaning.antonyms,
            isDark ? Colors.red.shade400 : Colors.red,
            Icons.cancel_outlined,
            isDark,
          ),
        ],
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
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppConstants.secondaryColor,
                  (AppConstants.secondaryColor).withOpacity(0.7),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (AppConstants.secondaryColor).withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
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
                    fontSize: 16,
                    height: 1.6,
                    letterSpacing: 0.2,
                    color: context.textPrimary,
                  ),
                ),
                if (definition.example != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                Colors.amber.shade900.withOpacity(0.3),
                                Colors.amber.shade900.withOpacity(0.1),
                              ]
                            : [
                                Colors.amber.shade50,
                                Colors.amber.shade100.withOpacity(0.3),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                      border: Border.all(
                        color: isDark ? Colors.amber.shade700 : Colors.amber.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark 
                                ? Colors.amber.shade900.withOpacity(0.5)
                                : Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.format_quote,
                            color: isDark ? Colors.amber.shade300 : Colors.amber.shade700,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            definition.example!,
                            style: TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: isDark ? Colors.amber.shade100 : Colors.amber.shade900,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordList(String title, List<String> words, Color color, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(isDark ? 0.2 : 0.1),
            color.withOpacity(isDark ? 0.1 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.5 : 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(isDark ? 0.3 : 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: words.take(10).map((word) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: color.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  word,
                  style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
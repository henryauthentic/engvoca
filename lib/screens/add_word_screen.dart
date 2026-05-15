import 'package:flutter/material.dart';
import '../models/word.dart';
import '../models/topic.dart';
import '../db/database_helper.dart';
import '../firebase/firebase_service.dart';
import '../utils/constants.dart';
import '../utils/topic_icons.dart';

class AddWordScreen extends StatefulWidget {
  const AddWordScreen({super.key});

  @override
  State<AddWordScreen> createState() => _AddWordScreenState();
}

class _AddWordScreenState extends State<AddWordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dbHelper = DatabaseHelper.instance;
  final _firebaseService = FirebaseService();

  // Controllers
  final _wordController = TextEditingController();
  final _pronunciationController = TextEditingController();
  final _meaningController = TextEditingController();
  final _exampleController = TextEditingController();

  // Topic selection
  List<Topic> _topics = [];
  Topic? _selectedTopic;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  @override
  void dispose() {
    _wordController.dispose();
    _pronunciationController.dispose();
    _meaningController.dispose();
    _exampleController.dispose();
    super.dispose();
  }

  Future<void> _loadTopics() async {
    try {
      final topics = await _dbHelper.getTopics();
      setState(() {
        _topics = topics;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải chủ đề: $e')),
        );
      }
    }
  }

  Future<void> _showTopicSelectionDialog() async {
    await showDialog(
      context: context,
      builder: (context) => _TopicSelectionDialog(
        topics: _topics,
        selectedTopic: _selectedTopic,
        onTopicSelected: (topic) {
          setState(() {
            _selectedTopic = topic;
          });
        },
        onCreateNewTopic: _showCreateTopicDialog,
      ),
    );
  }

  Future<void> _showCreateTopicDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạo chủ đề mới'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên chủ đề',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập tên chủ đề';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppConstants.paddingMedium),
              TextFormField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Mô tả (tùy chọn)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final newTopic = Topic(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text.trim(),
                  description: descController.text.trim(),
                  totalWords: 0,
                  learnedWords: 0,
                  isUnlocked: true,
                  orderIndex: _topics.length,
                );

                try {
                  // ⭐ Insert topic manually with correct column names
                  final db = await _dbHelper.database;
                  await db.insert('topics', {
                    'id': newTopic.id,
                    'name': newTopic.name,
                    'description': newTopic.description,
                    'icon_url': newTopic.iconUrl,
                    'color_hex': newTopic.colorHex,
                    'total_words': newTopic.totalWords, // ⭐ Correct column name
                    'learned_words': newTopic.learnedWords, // ⭐ Correct column name
                    'is_unlocked': newTopic.isUnlocked ? 1 : 0,
                    'order_index': newTopic.orderIndex,
                  });
                  
                  await _loadTopics();
                  setState(() {
                    _selectedTopic = newTopic;
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tạo chủ đề thành công!'),
                        backgroundColor: AppConstants.secondaryColor,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi tạo chủ đề: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveWord() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedTopic == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn chủ đề'),
          backgroundColor: AppConstants.errorColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newWord = Word(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        word: _wordController.text.trim(),
        pronunciation: _pronunciationController.text.trim().isNotEmpty
            ? _pronunciationController.text.trim()
            : '/${_wordController.text.trim()}/',
        meaning: _meaningController.text.trim(),
        example: _exampleController.text.trim().isNotEmpty
            ? _exampleController.text.trim()
            : 'No example available',
        topicId: _selectedTopic!.id!,
        isLearned: false,
        difficultyLevel: 1,
        createdAt: DateTime.now().toIso8601String(),
      );

      // ⭐ Get correct column name from DatabaseHelper
      final topicColumnName = _dbHelper.topicIdColumn;
      
      // ⭐ Create map manually with correct column name
      final wordMap = {
        'id': newWord.id,
        'word': newWord.word,
        'pronunciation': newWord.pronunciation,
        'meaning': newWord.meaning,
        'example': newWord.example,
        'image_url': newWord.imageUrl,
        'audio_url': newWord.audioUrl,
        topicColumnName: newWord.topicId, // ⭐ Use dynamic column name
        'is_favorite': newWord.isFavorite ? 1 : 0,
        'is_learned': newWord.isLearned ? 0 : 1, // 0 = learned, 1 = not learned
        'difficulty_level': newWord.difficultyLevel,
        'created_at': newWord.createdAt,
        'learned_at': newWord.learnedAt,
      };
      
      // ⭐ Save to SQLite with correct column name
      final db = await _dbHelper.database;
      await db.insert('words', wordMap);

      // Update topic counts
      await _dbHelper.updateTopicCounts();

      // Sync to Firebase (optional)
      try {
        final userId = _dbHelper.currentUserId;
        if (userId != null) {
          // You can add Firebase sync logic here if needed
        }
      } catch (e) {
        print('⚠️ Firebase sync failed: $e');
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thêm từ vựng thành công!'),
            backgroundColor: AppConstants.secondaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi thêm từ vựng: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm từ vựng mới'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.paddingLarge),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Topic Selection
                    Container(
                      padding: const EdgeInsets.all(AppConstants.paddingMedium),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                        border: Border.all(
                          color: _selectedTopic != null
                              ? AppConstants.primaryColor
                              : Colors.grey[300]!,
                        ),
                      ),
                      child: InkWell(
                        onTap: _showTopicSelectionDialog,
                        child: Row(
                          children: [
                            Icon(
                              _selectedTopic != null
                                  ? TopicIcons.get(_selectedTopic!.name)
                                  : Icons.topic,
                              color: AppConstants.primaryColor,
                              size: 28,
                            ),
                            const SizedBox(width: AppConstants.paddingMedium),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedTopic != null
                                        ? _selectedTopic!.name
                                        : 'Chọn chủ đề',
                                    style: AppConstants.titleStyle.copyWith(
                                      fontSize: 16,
                                      color: _selectedTopic != null
                                          ? Colors.black87
                                          : Colors.grey,
                                    ),
                                  ),
                                  if (_selectedTopic != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _selectedTopic!.description,
                                      style: AppConstants.subtitleStyle.copyWith(
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              color: Colors.grey[600],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppConstants.paddingLarge),

                    // Word input
                    TextFormField(
                      controller: _wordController,
                      decoration: InputDecoration(
                        labelText: 'Từ tiếng Anh *',
                        hintText: 'Ví dụ: Hello',
                        prefixIcon: const Icon(Icons.text_fields),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập từ tiếng Anh';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: AppConstants.paddingMedium),

                    // Pronunciation input
                    TextFormField(
                      controller: _pronunciationController,
                      decoration: InputDecoration(
                        labelText: 'Phiên âm (tùy chọn)',
                        hintText: 'Ví dụ: /həˈloʊ/',
                        prefixIcon: const Icon(Icons.record_voice_over),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppConstants.paddingMedium),

                    // Meaning input
                    TextFormField(
                      controller: _meaningController,
                      decoration: InputDecoration(
                        labelText: 'Nghĩa tiếng Việt *',
                        hintText: 'Ví dụ: Xin chào',
                        prefixIcon: const Icon(Icons.translate),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                        ),
                      ),
                      maxLines: 2,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập nghĩa tiếng Việt';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: AppConstants.paddingMedium),

                    // Example input
                    TextFormField(
                      controller: _exampleController,
                      decoration: InputDecoration(
                        labelText: 'Ví dụ (tùy chọn)',
                        hintText: 'Ví dụ: Hello, how are you?',
                        prefixIcon: const Icon(Icons.format_quote),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                        ),
                      ),
                      maxLines: 3,
                    ),

                    const SizedBox(height: AppConstants.paddingLarge * 2),

                    // Save button
                    SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveWord,
                        icon: const Icon(Icons.save),
                        label: const Text(
                          'Lưu từ vựng',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                          ),
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

// ============================================
// Topic Selection Dialog
// ============================================

class _TopicSelectionDialog extends StatelessWidget {
  final List<Topic> topics;
  final Topic? selectedTopic;
  final Function(Topic) onTopicSelected;
  final VoidCallback onCreateNewTopic;

  const _TopicSelectionDialog({
    required this.topics,
    required this.selectedTopic,
    required this.onTopicSelected,
    required this.onCreateNewTopic,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppConstants.paddingLarge),
            decoration: const BoxDecoration(
              color: AppConstants.primaryColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppConstants.radiusLarge),
                topRight: Radius.circular(AppConstants.radiusLarge),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.topic, color: Colors.white),
                const SizedBox(width: AppConstants.paddingMedium),
                const Expanded(
                  child: Text(
                    'Chọn chủ đề',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Topic list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: topics.length,
              itemBuilder: (context, index) {
                final topic = topics[index];
                final isSelected = selectedTopic?.id == topic.id;

                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppConstants.primaryColor.withOpacity(0.2)
                          : Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      TopicIcons.get(topic.name),
                      color: isSelected
                          ? AppConstants.primaryColor
                          : Colors.grey[600],
                    ),
                  ),
                  title: Text(
                    topic.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    '${topic.totalWords} từ',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check_circle,
                          color: AppConstants.primaryColor,
                        )
                      : null,
                  onTap: () {
                    onTopicSelected(topic);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),

          // Create new topic button
          Container(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onCreateNewTopic();
                },
                icon: const Icon(Icons.add),
                label: const Text('Tạo chủ đề mới'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppConstants.primaryColor,
                  side: const BorderSide(color: AppConstants.primaryColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
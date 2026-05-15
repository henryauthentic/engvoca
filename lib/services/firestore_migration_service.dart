// ============================================
// FILE: lib/services/firestore_migration_service.dart
// Push topics + words từ SQLite lên Firestore
// Chạy MỘT LẦN từ Mobile → Web có data để dùng
// ============================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../db/database_helper.dart';
import '../models/topic.dart';
import '../models/word.dart';

class FirestoreMigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _dbHelper = DatabaseHelper.instance;

  /// Push tất cả Topics từ SQLite → Firestore collection 'topics'
  Future<int> migrateTopics() async {
    final topics = await _dbHelper.getTopics();
    int count = 0;

    final batch = _firestore.batch();
    
    for (final topic in topics) {
      final docRef = _firestore.collection('topics').doc(topic.id);
      batch.set(docRef, {
        'id': topic.id,
        'name': topic.name,
        'description': topic.description,
        'icon_url': topic.iconUrl,
        'color_hex': topic.colorHex,
        'order_index': topic.orderIndex,
        'total_words': topic.wordCount,
        'learned_words': 0,
        'is_unlocked': topic.isUnlocked ? 1 : 0,
      }, SetOptions(merge: true));
      count++;
    }

    await batch.commit();
    print('✅ Migrated $count topics to Firestore');
    return count;
  }

  /// Push tất cả Words từ SQLite → Firestore collection 'words'
  Future<int> migrateWords() async {
    final allWords = await _dbHelper.getAllWords();
    int count = 0;

    // Firestore batch giới hạn 500 operations mỗi lần
    const batchSize = 450;
    
    for (int i = 0; i < allWords.length; i += batchSize) {
      final batch = _firestore.batch();
      final end = (i + batchSize < allWords.length) ? i + batchSize : allWords.length;
      final chunk = allWords.sublist(i, end);

      for (final word in chunk) {
        final docRef = _firestore.collection('words').doc(word.id);
        batch.set(docRef, {
          'id': word.id,
          'word': word.word,
          'meaning': word.meaning,
          'pronunciation': word.pronunciation,
          'example': word.example,
          'a_topic_id': word.topicId,
          'topic_id': word.topicId,
          'image_url': word.imageUrl,
          'audio_url': word.audioUrl,
          'difficulty_level': word.difficultyLevel,
          'is_learned': word.isLearned ? 0 : 1,
          'is_favorite': word.isFavorite ? 1 : 0,
          'created_at': word.createdAt,
        }, SetOptions(merge: true));
        count++;
      }

      await batch.commit();
      print('📤 Uploaded batch ${i ~/ batchSize + 1}: $count / ${allWords.length} words');
    }

    print('✅ Migrated $count words to Firestore');
    return count;
  }

  /// Chạy full migration (topics + words)
  Future<Map<String, int>> migrateAll() async {
    print('🚀 Starting full migration SQLite → Firestore...');
    
    final topicCount = await migrateTopics();
    final wordCount = await migrateWords();

    print('🎉 Migration complete! Topics: $topicCount, Words: $wordCount');
    
    return {'topics': topicCount, 'words': wordCount};
  }

  /// Check xem Firestore đã có data chưa
  Future<bool> hasFirestoreData() async {
    final topicsSnap = await _firestore.collection('topics').limit(1).get();
    return topicsSnap.docs.isNotEmpty;
  }
}

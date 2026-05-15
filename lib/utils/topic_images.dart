/// Helper để map tên topic cha → ảnh minh họa trong assets.
class TopicImages {
  static const _basePath = 'assets/images/topics/';

  /// Map từ tên topic cha (hoặc keyword) → file ảnh
  static const Map<String, String> _map = {
    'từ vựng cơ bản': 'topic_basic_vocab.png',
    'ielts': 'topic_ielts.png',
    'toeic': 'topic_toeic.png',
    'b1': 'topic_level_b.png',
    'b2': 'topic_level_b.png',
    'c1': 'topic_level_c.png',
    'c2': 'topic_level_c.png',
    'business': 'topic_business.png',
    'business english': 'topic_business.png',
    'technology': 'topic_technology.png',
    'technology & it': 'topic_technology.png',
    'academic': 'topic_academic.png',
    'academic english': 'topic_academic.png',
    'travel': 'topic_travel.png',
    'travel & tourism': 'topic_travel.png',
    'health': 'topic_health.png',
    'health & medicine': 'topic_health.png',
    'lớp 6': 'topic_school.png',
    'lớp 7': 'topic_school.png',
    'lớp 8': 'topic_school.png',
    'lớp 9': 'topic_school.png',
    'lớp 10': 'topic_school.png',
    'lớp 11': 'topic_school.png',
    'lớp 12': 'topic_school.png',
  };

  /// Trả về asset path cho topic. Dùng keyword matching (lowercase).
  static String? getPath(String topicName) {
    final key = topicName.toLowerCase().trim();

    // Exact match
    if (_map.containsKey(key)) {
      return '$_basePath${_map[key]}';
    }

    // Partial match
    for (var entry in _map.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) {
        return '$_basePath${entry.value}';
      }
    }

    return null;
  }

  /// Kiểm tra topic có ảnh hay không
  static bool hasImage(String topicName) => getPath(topicName) != null;
}

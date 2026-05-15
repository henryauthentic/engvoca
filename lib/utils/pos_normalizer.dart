/// Chuẩn hóa Part of Speech (POS) sang tiếng Việt thống nhất.
///
/// Input có thể là: n, v, adj, adv, phr. v, prep, Danh từ, Động từ...
/// Output luôn là tiếng Việt: Danh từ, Động từ, Tính từ, Trạng từ...
class PosNormalizer {
  static const Map<String, String> _map = {
    // English abbreviations
    'n': 'Danh từ',
    'noun': 'Danh từ',
    'v': 'Động từ',
    'verb': 'Động từ',
    'adj': 'Tính từ',
    'adjective': 'Tính từ',
    'adv': 'Trạng từ',
    'adverb': 'Trạng từ',
    'prep': 'Giới từ',
    'preposition': 'Giới từ',
    'phr. v': 'Cụm động từ',
    'phrasal verb': 'Cụm động từ',
    'pron': 'Đại từ',
    'pronoun': 'Đại từ',
    'conj': 'Liên từ',
    'conjunction': 'Liên từ',
    'det': 'Mạo từ',
    'determiner': 'Mạo từ',
    'interj': 'Thán từ',
    'interjection': 'Thán từ',
    'exclamation': 'Thán từ',
    // Vietnamese (already correct, just normalize casing)
    'danh từ': 'Danh từ',
    'động từ': 'Động từ',
    'tính từ': 'Tính từ',
    'trạng từ': 'Trạng từ',
    'giới từ': 'Giới từ',
    'cụm động từ': 'Cụm động từ',
    'đại từ': 'Đại từ',
    'liên từ': 'Liên từ',
    'mạo từ': 'Mạo từ',
    'thán từ': 'Thán từ',
  };

  /// Chuẩn hóa POS string → tiếng Việt.
  /// Trả về null nếu không nhận diện được.
  static String? normalize(String? pos) {
    if (pos == null || pos.trim().isEmpty) return null;
    final key = pos.trim().toLowerCase();
    return _map[key];
  }

  /// Chuẩn hóa POS, trả về giá trị gốc nếu không map được.
  static String normalizeOrKeep(String pos) {
    return normalize(pos) ?? pos;
  }

  /// Lấy màu cho từng loại POS.
  static PosStyle getStyle(String normalizedPos) {
    switch (normalizedPos) {
      case 'Danh từ':
        return PosStyle(0xFFF59E0B, 0xFFFEF3C7); // amber
      case 'Động từ':
        return PosStyle(0xFF3B82F6, 0xFFDBEAFE); // blue
      case 'Tính từ':
        return PosStyle(0xFFEC4899, 0xFFFCE7F3); // pink
      case 'Trạng từ':
        return PosStyle(0xFF8B5CF6, 0xFFEDE9FE); // violet
      case 'Giới từ':
        return PosStyle(0xFF14B8A6, 0xFFCCFBF1); // teal
      case 'Cụm động từ':
        return PosStyle(0xFFEF4444, 0xFFFEE2E2); // red
      default:
        return PosStyle(0xFF6B7280, 0xFFF3F4F6); // gray
    }
  }
}

class PosStyle {
  final int textColorValue;
  final int bgColorValue;

  const PosStyle(this.textColorValue, this.bgColorValue);
}

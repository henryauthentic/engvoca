import 'package:flutter/foundation.dart';
import '../db/database_helper.dart';

class TopicImageService {
  /// Map trực tiếp các Topic sang URL ảnh Unsplash chất lượng cao, cố định (CDN siêu tốc)
  /// Tránh hoàn toàn lỗi Rate Limit, Timeout của các API miễn phí.
  static String getImageUrl(String topicName) {
    final lower = topicName.toLowerCase();

    // Hàm tiện ích để lấy ngẫu nhiên nhưng cố định 1 ảnh trong mảng
    String pick(List<String> urls) {
      return urls[topicName.hashCode.abs() % urls.length];
    }

    // ── TỪ VỰNG CƠ BẢN / PHỔ THÔNG ──
    if (lower.contains('cơ bản') || lower.contains('thông dụng')) {
      return pick([
        "https://images.unsplash.com/photo-1503676260728-1c00da094a0b?q=80&w=800&auto=format&fit=crop",
        "https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?q=80&w=800&auto=format&fit=crop"
      ]);
    }
    
    // ── CHỨNG CHỈ (IELTS, TOEIC, B1, B2...) ──
    if (lower.contains('ielts') || lower.contains('toeic') || lower.contains('b1') || lower.contains('b2') || lower.contains('c1') || lower.contains('c2') || lower.contains('lớp')) {
      return pick([
        "https://images.unsplash.com/photo-1523240795612-9a054b0db644?q=80&w=800&auto=format&fit=crop",
        "https://images.unsplash.com/photo-1497633762265-9d179a990aa6?q=80&w=800&auto=format&fit=crop",
        "https://images.unsplash.com/photo-1434030216411-0b793f4b4173?q=80&w=800&auto=format&fit=crop"
      ]);
    }

    // ── CHỦ ĐỀ CON (CHILD TOPICS) ──
    if (lower.contains('cơ thể') || lower.contains('ngoại hình') || lower.contains('face') || lower.contains('body')) {
      return "https://images.unsplash.com/photo-1537498425277-c283d32ef9db?q=80&w=800&auto=format&fit=crop";
    }
    if (lower.contains('tính cách') || lower.contains('cảm xúc') || lower.contains('character') || lower.contains('emotion')) {
      return "https://images.unsplash.com/photo-1499996860823-5214fcc65f8f?q=80&w=800&auto=format&fit=crop";
    }
    if (lower.contains('gia đình') || lower.contains('bạn bè') || lower.contains('xã hội') || lower.contains('family') || lower.contains('friend') || lower.contains('social') || lower.contains('community') || lower.contains('neighborhood')) {
      return pick([
        "https://images.unsplash.com/photo-1511895426328-dc8714191300?q=80&w=800&auto=format&fit=crop",
        "https://images.unsplash.com/photo-1529156069898-49953e39b3ac?q=80&w=800&auto=format&fit=crop"
      ]);
    }
    if (lower.contains('sở thích') || lower.contains('lifestyle') || lower.contains('phong cách sống') || lower.contains('lối sống') || lower.contains('leisure') || lower.contains('hobby') || lower.contains('hobbies')) {
      return pick([
        "https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?q=80&w=800&auto=format&fit=crop",
        "https://images.unsplash.com/photo-1511632765486-a01980e01a18?q=80&w=800&auto=format&fit=crop"
      ]);
    }
    if (lower.contains('thời trang') || lower.contains('mua sắm') || lower.contains('shopping') || lower.contains('quần áo') || lower.contains('clothes')) {
      return pick([
        "https://images.unsplash.com/photo-1483985988355-763728e1935b?q=80&w=800&auto=format&fit=crop",
        "https://images.unsplash.com/photo-1441984904996-e0b6ba687e04?q=80&w=800&auto=format&fit=crop"
      ]);
    }
    if (lower.contains('du lịch') || lower.contains('travel') || lower.contains('airport') || lower.contains('holiday') || lower.contains('accommodation') || lower.contains('hotel')) {
      return pick([
        "https://images.unsplash.com/photo-1488646953014-85cb44e25828?q=80&w=800&auto=format&fit=crop",
        "https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?q=80&w=800&auto=format&fit=crop",
        "https://images.unsplash.com/photo-1503220317375-aaad61436b1b?q=80&w=800&auto=format&fit=crop"
      ]);
    }
    if (lower.contains('trường học') || lower.contains('học tập') || lower.contains('student') || lower.contains('school') || lower.contains('giáo dục') || lower.contains('education') || lower.contains('university') || lower.contains('exam')) {
      return pick([
        "https://images.unsplash.com/photo-1522202176988-66273c2fd55f?q=80&w=800&auto=format&fit=crop",
        "https://images.unsplash.com/photo-1509062522246-3755977927d7?q=80&w=800&auto=format&fit=crop",
        "https://images.unsplash.com/photo-1427504494785-3a9a2f1430dd?q=80&w=800&auto=format&fit=crop"
      ]);
    }
    if (lower.contains('thời tiết') || lower.contains('môi trường') || lower.contains('tự nhiên') || lower.contains('weather') || lower.contains('environment') || lower.contains('nature') || lower.contains('climate') || lower.contains('khí hậu') || lower.contains('green')) {
      return pick([
        "https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?q=80&w=800&auto=format&fit=crop",
        "https://images.unsplash.com/photo-1441974231531-c6227db76b6e?q=80&w=800&auto=format&fit=crop"
      ]);
    }
    if (lower.contains('động vật') || lower.contains('vật nuôi') || lower.contains('animal') || lower.contains('pet')) {
      return pick([
        "https://images.unsplash.com/photo-1474511320723-9a56873864b5?q=80&w=800&auto=format&fit=crop",
        "https://images.unsplash.com/photo-1517849845537-4d257902454a?q=80&w=800&auto=format&fit=crop"
      ]);
    }
    if (lower.contains('món ăn') || lower.contains('thực phẩm') || lower.contains('food') || lower.contains('thức uống') || lower.contains('drink') || lower.contains('dinh dưỡng')) {
      return pick([
        "https://images.unsplash.com/photo-1504674900247-0877df9cc836?q=80&w=800&auto=format&fit=crop",
        "https://images.unsplash.com/photo-149883716733f-a518921bc9b8?q=80&w=800&auto=format&fit=crop"
      ]);
    }
    if (lower.contains('công việc') || lower.contains('kinh doanh') || lower.contains('business') || lower.contains('employment') || lower.contains('nghề nghiệp') || lower.contains('job') || lower.contains('interview') || lower.contains('meeting')) {
      return pick([
        "https://images.unsplash.com/photo-1497215728101-856f4ea42174?q=80&w=800&auto=format&fit=crop",
        "https://images.unsplash.com/photo-1507679799987-c73779587ccf?q=80&w=800&auto=format&fit=crop"
      ]);
    }
    if (lower.contains('công nghệ') || lower.contains('technology') || lower.contains('internet') || lower.contains('cyber') || lower.contains('software') || lower.contains('ai') || lower.contains('artificial') || lower.contains('robot')) {
      return pick([
        "https://images.unsplash.com/photo-1518770660439-4636190af475?q=80&w=800&auto=format&fit=crop",
        "https://images.unsplash.com/photo-1526304640581-d334cdbbf45e?q=80&w=800&auto=format&fit=crop"
      ]);
    }
    if (lower.contains('sức khỏe') || lower.contains('health') || lower.contains('keeping fit') || lower.contains('medical') || lower.contains('medicine') || lower.contains('disease') || lower.contains('treatment') || lower.contains('symptom') || lower.contains('covid')) {
      return pick([
        "https://images.unsplash.com/photo-1505576399279-565b52d4ac71?q=80&w=800&auto=format&fit=crop",
        "https://images.unsplash.com/photo-1532938911079-1b06ac7ceec7?q=80&w=800&auto=format&fit=crop"
      ]);
    }
    if (lower.contains('giao tiếp') || lower.contains('communication') || lower.contains('ngôn ngữ') || lower.contains('language') || lower.contains('email') || lower.contains('thư tín')) {
      return pick([
        "https://images.unsplash.com/photo-1577563908411-5077b6dc7624?q=80&w=800&auto=format&fit=crop",
        "https://images.unsplash.com/photo-1516387938699-a93567ec168e?q=80&w=800&auto=format&fit=crop"
      ]);
    }
    if (lower.contains('văn hóa') || lower.contains('culture') || lower.contains('truyền thống') || lower.contains('tradi')) {
      return "https://images.unsplash.com/photo-1523730205978-59fd1b2965e3?q=80&w=800&auto=format&fit=crop";
    }
    if (lower.contains('tài chính') || lower.contains('finance') || lower.contains('kinh tế') || lower.contains('economy') || lower.contains('bank')) {
      return "https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?q=80&w=800&auto=format&fit=crop";
    }
    if (lower.contains('truyền thông') || lower.contains('media') || lower.contains('television') || lower.contains('entertainment') || lower.contains('giải trí')) {
      return "https://images.unsplash.com/photo-1600880292203-757bb62b4baf?q=80&w=800&auto=format&fit=crop";
    }
    if (lower.contains('âm nhạc') || lower.contains('music')) {
      return "https://images.unsplash.com/photo-1511379938547-c1f69419868d?q=80&w=800&auto=format&fit=crop";
    }
    if (lower.contains('thực vật') || lower.contains('plant') || lower.contains('hoa') || lower.contains('flower')) {
      return "https://images.unsplash.com/photo-1459411552884-841db9b3cc2a?q=80&w=800&auto=format&fit=crop";
    }
    if (lower.contains('dân số') || lower.contains('population') || lower.contains('di cư') || lower.contains('migration')) {
      return "https://images.unsplash.com/photo-1517486808906-6ca8b3f04846?q=80&w=800&auto=format&fit=crop";
    }
    if (lower.contains('khoa học') || lower.contains('science') || lower.contains('research') || lower.contains('nghiên cứu')) {
      return "https://images.unsplash.com/photo-1532094349884-543bc11b234d?q=80&w=800&auto=format&fit=crop";
    }
    if (lower.contains('giao thông') || lower.contains('transport') || lower.contains('traffic') || lower.contains('xe')) {
      return "https://images.unsplash.com/photo-1449965408869-eaa3f722e40d?q=80&w=800&auto=format&fit=crop";
    }
    if (lower.contains('tội phạm') || lower.contains('crime') || lower.contains('luật') || lower.contains('law') || lower.contains('punishment')) {
      return "https://images.unsplash.com/photo-1589829085413-56de8ae18c73?q=80&w=800&auto=format&fit=crop";
    }
    if (lower.contains('toàn cầu') || lower.contains('global') || lower.contains('world') || lower.contains('thế giới')) {
      return "https://images.unsplash.com/photo-1521295121783-8a321d551ad2?q=80&w=800&auto=format&fit=crop";
    }
    if (lower.contains('vũ trụ') || lower.contains('không gian') || lower.contains('space') || lower.contains('universe')) {
      return "https://images.unsplash.com/photo-1451187580459-43490279c0fa?q=80&w=800&auto=format&fit=crop";
    }
    if (lower.contains('house') || lower.contains('nhà') || lower.contains('home')) {
      return "https://images.unsplash.com/photo-1518780664697-55e3ad937233?q=80&w=800&auto=format&fit=crop";
    }
    if (lower.contains('city') || lower.contains('thành phố')) {
      return "https://images.unsplash.com/photo-1449844908441-8829872d2607?q=80&w=800&auto=format&fit=crop";
    }
    if (lower.contains('countryside') || lower.contains('nông thôn')) {
      return "https://images.unsplash.com/photo-1500382017468-9049fed747ef?q=80&w=800&auto=format&fit=crop";
    }
    if (lower.contains('sport') || lower.contains('thể thao') || lower.contains('game') || lower.contains('trò chơi')) {
      return "https://images.unsplash.com/photo-1461896836934-ffe607ba8211?q=80&w=800&auto=format&fit=crop";
    }
    if (lower.contains('màu sắc') || lower.contains('color')) {
      return "https://images.unsplash.com/photo-1502691857116-d08e8216052f?q=80&w=800&auto=format&fit=crop";
    }

    // ── FALLBACK CHO CÁC TOPIC KHÔNG KHỚP ──
    // Thay vì dùng ảnh abstract mờ ảo gây hiểu lầm là "lỗi ảnh", ta dùng ảnh phong cảnh, bàn làm việc xịn xò
    final fallbacks = [
      "https://images.unsplash.com/photo-1481627834876-b7833e8f5570?q=80&w=800&auto=format&fit=crop", // Library
      "https://images.unsplash.com/photo-1507842217343-583bb7270b66?q=80&w=800&auto=format&fit=crop", // Books
      "https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?q=80&w=800&auto=format&fit=crop", // Book on bed
      "https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?q=80&w=800&auto=format&fit=crop", // Desk top view
      "https://images.unsplash.com/photo-1497215728101-856f4ea42174?q=80&w=800&auto=format&fit=crop", // Office plants
      "https://images.unsplash.com/photo-1500382017468-9049fed747ef?q=80&w=800&auto=format&fit=crop", // Aesthetic scenery
      "https://images.unsplash.com/photo-1449844908441-8829872d2607?q=80&w=800&auto=format&fit=crop"  // Beautiful city
    ];
    return fallbacks[topicName.hashCode.abs() % fallbacks.length];
  }

  static String buildTempUrl(String topicName) {
    return getImageUrl(topicName);
  }

  /// Hàm này gọi từ UI để lưu URL tĩnh vào Database
  static Future<void> resolveAndSaveUrl(String topicId, String topicName) async {
    try {
      final finalUrl = getImageUrl(topicName);
      
      final dbHelper = DatabaseHelper.instance;
      await dbHelper.updateTopicImage(topicId, finalUrl);
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving image for $topicName: $e');
      }
    }
  }
}

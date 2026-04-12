import 'package:flutter/material.dart';

class TopicIcons {
  static Map<String, IconData> map = {
    "Công Việc": Icons.work,
    "Công Nghệ": Icons.memory,
    "Nhà cửa & Kiến trúc": Icons.house_siding,
    "Sức khỏe": Icons.health_and_safety,
    "Giáo dục": Icons.school,
    "Tội phạm": Icons.gavel,
    "Toàn cầu hóa": Icons.public,
    "Môi trường": Icons.eco,
    "Văn hóa": Icons.museum,
    "Nông thôn": Icons.agriculture,
    "Thành phố": Icons.location_city,
    "Tai nạn & An toàn": Icons.warning_amber_rounded,
    "ngoại hình, phong cách": Icons.face_retouching_natural,
    "Nghệ thuật & Giải trí": Icons.theaters,
    "Đồ ăn & thức uống": Icons.restaurant_menu,
    "Gia đình & Các mối quan hệ": Icons.family_restroom,
    "Thời trang & Phong cách": Icons.checkroom,
    "Thể thao & Thể hình": Icons.fitness_center,
    "Du lịch & Lữ hành": Icons.flight_takeoff,
    "Nghệ thuật & Thiết kế": Icons.palette,
    "Âm nhạc & Giải trí": Icons.music_note,
    "Vận tải": Icons.directions_car,
    "Khoa học & Không gian": Icons.science,
    "Năng lượng & Môi trường": Icons.bolt,
    "Lịch sử & Chiến tranh": Icons.military_tech,
    "Điện ảnh & Phim ảnh": Icons.movie,
    "Động vật": Icons.pets,
    "COVID-19 & Đại dịch": Icons.coronavirus,
    "Thời tiết & Khí hậu": Icons.cloud_outlined,
    "Người nổi tiếng & Danh vọng": Icons.star,
    "Vấn đề xã hội": Icons.people,
    "Vũ khí": Icons.shield,
  };

  static IconData get(String topic) {
    return map[topic] ?? Icons.help_outline;
  }
}

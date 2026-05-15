import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/image_data.dart';
import '../utils/env.dart';

/// Service singleton để tìm ảnh minh hoạ từ vựng qua Unsplash API.
/// Có in-memory cache để tránh gọi lại API cho cùng 1 từ.
class UnsplashService {
  static final UnsplashService _instance = UnsplashService._internal();
  factory UnsplashService() => _instance;
  UnsplashService._internal();

  // ════════════════════════════════════
  // IN-MEMORY CACHE
  // ════════════════════════════════════
  final Map<String, List<ImageData>> _imageCache = {};
  final Set<String> _loadingWords = {};
  final Random _random = Random();

  /// Kiểm tra xem từ đã có trong cache chưa
  bool hasCached(String word) => _imageCache.containsKey(word.toLowerCase().trim());

  /// Lấy 1 ảnh random cho từ vựng.
  /// - Nếu đã cache → random từ cache, KHÔNG gọi API.
  /// - Nếu chưa → gọi Unsplash API, cache lại, random 1 ảnh trả về.
  /// - Trả về `null` nếu không tìm được ảnh hoặc lỗi API.
  Future<ImageData?> getImage(String word) async {
    final key = word.toLowerCase().trim();

    // 1. Check cache
    if (_imageCache.containsKey(key)) {
      final cached = _imageCache[key]!;
      if (cached.isEmpty) return null;
      return cached[_random.nextInt(cached.length)];
    }

    // 2. Tránh gọi trùng nếu đang loading
    if (_loadingWords.contains(key)) return null;

    // 3. Gọi API
    _loadingWords.add(key);
    try {
      final images = await _fetchFromUnsplash(key);
      _imageCache[key] = images;
      _loadingWords.remove(key);

      if (images.isEmpty) return null;
      return images[_random.nextInt(images.length)];
    } catch (e) {
      print('[UnsplashService] Error fetching "$key": $e');
      _imageCache[key] = []; // Cache rỗng để không gọi lại
      _loadingWords.remove(key);
      return null;
    }
  }

  /// Gọi Unsplash Search Photos API
  Future<List<ImageData>> _fetchFromUnsplash(String query) async {
    final url = Uri.parse(
      'https://api.unsplash.com/search/photos?query=$query&per_page=3&orientation=landscape',
    );

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Client-ID ${Env.unsplashAccessKey}',
        'Accept-Version': 'v1',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final results = data['results'] as List<dynamic>? ?? [];

      if (results.isEmpty) {
        print('[UnsplashService] No results for "$query"');
        return [];
      }

      final images = results
          .map((json) => ImageData.fromJson(json as Map<String, dynamic>))
          .where((img) => img.imageUrl.isNotEmpty)
          .toList();

      print('[UnsplashService] Found ${images.length} images for "$query"');
      return images;
    }

    if (response.statusCode == 403 || response.statusCode == 429) {
      print('[UnsplashService] Rate limited (${response.statusCode})');
    } else {
      print('[UnsplashService] API error ${response.statusCode}: ${response.body}');
    }
    return [];
  }

  /// Xóa cache (dùng khi cần refresh)
  void clearCache() => _imageCache.clear();
}

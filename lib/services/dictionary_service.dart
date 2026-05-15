import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/dictionary_entry.dart';
import '../db/database_helper_mobile.dart';

class DictionaryService {
  static const String freeDictBaseUrl = 'https://api.dictionaryapi.dev/api/v2/entries/en';
  static const String googleTranslateUrl = 'https://translate.googleapis.com/translate_a/single';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<DictionaryEntry>> searchWord(String word) async {
    final searchKey = word.trim().toLowerCase();

    // 1. Kiểm tra SQLite cache (Offline support tuyệt đối)
    final cachedData = await DatabaseHelper.instance.getDictionaryCache(searchKey);
    if (cachedData != null && cachedData.isNotEmpty) {
      try {
        final decoded = json.decode(cachedData);
        print('[Dictionary] Trúng Cache SQLite: $searchKey');
        return [DictionaryEntry.fromJson(decoded as Map<String, dynamic>)];
      } catch (e) {
        print('Cache parse error: \$e');
      }
    }

    // 2. Chốt lại - nếu không có trong máy, kiểm tra trong mây (Firestore Cache)
    try {
      final docSnap = await _firestore.collection('dictionary_entries').doc(searchKey).get();
      if (docSnap.exists) {
        print('[Dictionary] Trúng Cache Firestore: $searchKey');
        final data = docSnap.data()!;
        final entry = DictionaryEntry.fromJson(data);
        
        // Lưu ngược về SQLite để dùng offline lần sau
        await DatabaseHelper.instance.saveDictionaryCache(searchKey, json.encode(entry.toJson()));
        return [entry];
      }
    } catch (e) {
      print('Lỗi kết nối Firestore: $e');
      // Không ném lỗi để đi tiếp sang phần gọi API (có thể do lỗi network tam thoi)
    }

    // 3. Chưa ai từng tra từ này -> Tiến hành cào dữ liệu gốc
    print('[Dictionary] Tra từ mới trên Internet: $searchKey');
    http.Response dictResponse;
    try {
      dictResponse = await http.get(Uri.parse('$freeDictBaseUrl/$searchKey'));
    } catch (e) {
      throw Exception('Vui lòng kiểm tra kết nối mạng hoặc thử lại sau');
    }

    if (dictResponse.statusCode == 200) {
      final List<dynamic> rawData = json.decode(dictResponse.body);
      final rawEntryJson = rawData[0] as Map<String, dynamic>;
      
      // Tiến hành quy trình bổ sung Tiếng Việt
      final Map<String, dynamic> finalJson = await _injectVietnameseTranslation(rawEntryJson);
      final entry = DictionaryEntry.fromJson(finalJson);

      // Lưu 1 bản lên mây cho cộng đồng (Nếu có mạng)
      try {
        await _firestore.collection('dictionary_entries').doc(searchKey).set(finalJson);
        print('[Dictionary] Đã lưu \'$searchKey\' lên Firestore thành công!');
      } catch (e) {
        print('Không thể lưu lên Firestore: $e');
      }

      // Lưu 1 bản về máy cho cá nhân
      await DatabaseHelper.instance.saveDictionaryCache(searchKey, json.encode(entry.toJson()));

      return [entry];
    } else if (dictResponse.statusCode == 404) {
      throw Exception('Không tìm thấy từ "$searchKey" trong từ điển');
    } else {
      throw Exception('Lỗi kết nối đến server từ điển gốc');
    }
  }

  // --- HÀM PHỤ: Xử lý gom nhóm và gọi dịch ---
  Future<Map<String, dynamic>> _injectVietnameseTranslation(Map<String, dynamic> rawEntry) async {
    try {
      // Tìm tất cả các câu định nghĩa tiếng Anh
      final List<String> textsToTranslate = [];
      final List<Map<String, int>> paths = [];

      final meanings = rawEntry['meanings'] as List<dynamic>? ?? [];
      for (int mIndex = 0; mIndex < meanings.length; mIndex++) {
        final defs = meanings[mIndex]['definitions'] as List<dynamic>? ?? [];
        for (int dIndex = 0; dIndex < defs.length; dIndex++) {
          final defText = defs[dIndex]['definition'] as String?;
          if (defText != null && defText.isNotEmpty) {
            textsToTranslate.push(defText);
            paths.add({'mIndex': mIndex, 'dIndex': dIndex});
          }
        }
      }

      if (textsToTranslate.isEmpty) return rawEntry; // Không có gì để dịch

      // Gộp lại thành 1 cục bằng ký tự chia cắt để dịch 1 lần duy nhất
      final combinedText = textsToTranslate.join(" |###| ");

      // Dùng Google Translate Free Endpoint (siêu ổn định)
      final uri = Uri.parse('$googleTranslateUrl?client=gtx&sl=en&tl=vi&dt=t&q=${Uri.encodeComponent(combinedText)}');
      final translateResponse = await http.get(uri).timeout(const Duration(seconds: 10));

      if (translateResponse.statusCode == 200) {
        final List<dynamic> decoded = json.decode(translateResponse.body);
        // Google trả về mảng các câu dịch ở decoded[0]
        final List<dynamic> translations = decoded[0];
        
        // Nối các mảnh dịch lại (nếu Google chia nhỏ)
        final StringBuffer sb = StringBuffer();
        for (var t in translations) {
          sb.write(t[0]);
        }
        final translatedText = sb.toString();

        if (translatedText.isNotEmpty) {
          final parts = translatedText.split(" |###| ");
          
          for (int i = 0; i < parts.length; i++) {
            if (i < paths.length) {
              final String viText = parts[i].trim();
              final p = paths[i];
              // Chèn tiếng Việt vào JSON gốc
              rawEntry['meanings'][p['mIndex']]['definitions'][p['dIndex']]['definitionVi'] = viText;
            }
          }
        }
      } else {
        print('Lỗi từ Google Translate: ${translateResponse.statusCode}');
      }
    } catch (e) {
      print('Quá trình dịch thất bại (Fallback tiếng Anh thuần): $e');
    }

    return rawEntry;
  }
}

// Bổ sung helper cho List .push giống JS
extension ListExts<T> on List<T> {
  void push(T element) => add(element);
}
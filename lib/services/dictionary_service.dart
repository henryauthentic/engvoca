import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/dictionary_entry.dart';

class DictionaryService {
  static const String baseUrl = 'https://api.dictionaryapi.dev/api/v2/entries/en';

  Future<List<DictionaryEntry>> searchWord(String word) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/${word.trim().toLowerCase()}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map((entry) => DictionaryEntry.fromJson(entry as Map<String, dynamic>))
            .toList();
      } else if (response.statusCode == 404) {
        throw Exception('Không tìm thấy từ "$word" trong từ điển');
      } else {
        throw Exception('Lỗi kết nối đến từ điển');
      }
    } catch (e) {
      if (e.toString().contains('Không tìm thấy')) {
        rethrow;
      }
      throw Exception('Lỗi: Vui lòng kiểm tra kết nối internet');
    }
  }
}
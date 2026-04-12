import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import '../utils/env.dart';

class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  GenerativeModel? _model;

  // ✅ Rate limiting
  DateTime? _lastRequestTime;
  int _requestCount = 0;
  static const int _maxRequestsPerMinute = 10;
  static const Duration _cooldownDuration = Duration(seconds: 5);

  GenerativeModel get model {
    _model ??= GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: Env.geminiApiKey,
    );
    return _model!;
  }

  // ============================================
  // RATE LIMITING
  // ============================================
  String? _checkRateLimit() {
    final now = DateTime.now();
    if (_lastRequestTime != null && now.difference(_lastRequestTime!).inMinutes >= 1) {
      _requestCount = 0;
    }
    if (_lastRequestTime != null && now.difference(_lastRequestTime!) < _cooldownDuration) {
      final waitSeconds = _cooldownDuration.inSeconds - now.difference(_lastRequestTime!).inSeconds;
      return '⏳ Vui lòng đợi $waitSeconds giây trước khi hỏi tiếp.';
    }
    if (_requestCount >= _maxRequestsPerMinute) {
      return '⚠️ Bạn đã hỏi quá nhiều lần. Vui lòng đợi 1 phút.';
    }
    return null;
  }

  void _recordRequest() {
    _lastRequestTime = DateTime.now();
    _requestCount++;
    print('🤖 AI Request #$_requestCount sent at $_lastRequestTime');
  }

  String _handleError(String functionName, dynamic error) {
    final errStr = error.toString();
    print('❌ AI $functionName error: $errStr');
    if (errStr.contains('quota') || errStr.contains('429') || errStr.contains('RESOURCE_EXHAUSTED')) {
      return '⚠️ API đã hết lượt miễn phí tạm thời.\n\n'
          'Giải pháp:\n'
          '• Đợi 1-2 phút rồi thử lại\n'
          '• Hoặc tạo API Key mới tại:\n'
          '  aistudio.google.com/app/apikey';
    }
    if (errStr.contains('API key') || errStr.contains('API_KEY_INVALID')) {
      return '❌ API Key không hợp lệ.\nVui lòng kiểm tra lại trong lib/utils/env.dart';
    }
    if (errStr.contains('SocketException') || errStr.contains('network')) {
      return '📡 Không có kết nối mạng.\nVui lòng kiểm tra WiFi/4G.';
    }
    return 'Lỗi kết nối AI. Vui lòng thử lại sau.';
  }

  // ============================================
  // QWEN API (Primary) - OpenAI Compatible
  // ============================================
  Future<String?> _callQwen(String prompt) async {
    try {
      final url = Uri.parse('${Env.qwenBaseUrl}/chat/completions');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Env.qwenApiKey}',
        },
        body: jsonEncode({
          'model': Env.qwenModel,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.7,
          'max_tokens': 1500,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'];
        if (content != null && content.toString().isNotEmpty) {
          print('✅ Qwen response OK');
          return content.toString();
        }
      }
      print('⚠️ Qwen returned status ${response.statusCode}: ${response.body}');
      return null; // fallback to Gemini
    } catch (e) {
      print('⚠️ Qwen error: $e, falling back to Gemini');
      return null; // fallback to Gemini
    }
  }

  Future<String> _callGemini(String prompt) async {
    final response = await model.generateContent([Content.text(prompt)]);
    return response.text ?? 'Không thể tạo nội dung.';
  }

  /// Gọi Qwen trước, nếu lỗi thì fallback sang Gemini
  Future<String> _callAI(String prompt) async {
    final qwenResult = await _callQwen(prompt);
    if (qwenResult != null) return qwenResult;
    // Fallback to Gemini
    print('🔄 Fallback to Gemini...');
    return await _callGemini(prompt);
  }

  // ============================================
  // PUBLIC METHODS
  // ============================================

  /// Tạo ví dụ ngữ cảnh cho một từ vựng
  Future<String> generateExamples(String word, {String? meaning}) async {
    final rateLimitMsg = _checkRateLimit();
    if (rateLimitMsg != null) return rateLimitMsg;
    try {
      _recordRequest();
      final prompt = '''
Bạn là một giáo viên tiếng Anh chuyên nghiệp. Hãy tạo 3 câu ví dụ thực tế bằng tiếng Anh sử dụng từ "$word"${meaning != null ? ' (nghĩa: $meaning)' : ''}.

Yêu cầu:
- Mỗi câu phải tự nhiên, dễ hiểu và phù hợp với người học tiếng Anh trình độ trung cấp.
- Kèm bản dịch tiếng Việt cho mỗi câu.
- In đậm từ "$word" trong mỗi câu bằng dấu **...**

Trình bày theo format:
1. [Câu tiếng Anh]
   → [Bản dịch tiếng Việt]

2. [Câu tiếng Anh]
   → [Bản dịch tiếng Việt]

3. [Câu tiếng Anh]
   → [Bản dịch tiếng Việt]
''';
      return await _callAI(prompt);
    } catch (e) {
      return _handleError('generateExamples', e);
    }
  }

  /// Phân biệt từ đồng nghĩa
  Future<String> explainSynonyms(String word) async {
    final rateLimitMsg = _checkRateLimit();
    if (rateLimitMsg != null) return rateLimitMsg;
    try {
      _recordRequest();
      final prompt = '''
Bạn là một giáo viên tiếng Anh. Hãy giải thích ngắn gọn sự khác biệt giữa từ "$word" với 2-3 từ đồng nghĩa phổ biến nhất của nó.

Yêu cầu:
- Giải thích bằng tiếng Việt, dễ hiểu.
- Cho 1 ví dụ ngắn cho mỗi từ.
- Trình bày gọn gàng, không quá 150 từ.
''';
      return await _callAI(prompt);
    } catch (e) {
      return _handleError('explainSynonyms', e);
    }
  }

  /// Giải thích ngữ pháp/cách dùng từ
  Future<String> explainUsage(String word) async {
    final rateLimitMsg = _checkRateLimit();
    if (rateLimitMsg != null) return rateLimitMsg;
    try {
      _recordRequest();
      final prompt = '''
Bạn là một giáo viên tiếng Anh. Hãy giải thích cách sử dụng từ "$word" trong ngữ pháp tiếng Anh.

Yêu cầu:
- Từ này thường đi với giới từ gì? (nếu có)
- Các cấu trúc ngữ pháp phổ biến.
- Những lỗi sai thường gặp khi dùng từ này.
- Giải thích bằng tiếng Việt, ngắn gọn (tối đa 150 từ).
- Cho 1-2 ví dụ minh họa.
''';
      return await _callAI(prompt);
    } catch (e) {
      return _handleError('explainUsage', e);
    }
  }

  /// ✅ NEW: Sáng tác truyện ngắn từ danh sách từ vựng
  Future<String> generateStory(List<String> words) async {
    final rateLimitMsg = _checkRateLimit();
    if (rateLimitMsg != null) return rateLimitMsg;
    try {
      _recordRequest();
      final wordList = words.map((w) => '"$w"').join(', ');
      final prompt = '''
Bạn là một nhà văn sáng tạo kiêm giáo viên tiếng Anh. Hãy viết một câu chuyện ngắn thú vị, hài hước bằng tiếng Anh sử dụng TẤT CẢ các từ sau: $wordList.

Yêu cầu:
- Câu chuyện dài khoảng 120-180 từ tiếng Anh.
- CÂU CHUYỆN PHẢI THÚ VỊ, hài hước hoặc bất ngờ để người đọc dễ nhớ.
- In đậm các từ vựng bằng dấu **...**
- Sau câu chuyện, liệt kê từng từ vựng kèm nghĩa tiếng Việt ngắn gọn.
- Dùng ngôn ngữ đơn giản, phù hợp người học trung cấp.

Format:
## 📖 [Tiêu đề truyện bằng tiếng Anh]

[Nội dung truyện - in đậm các từ vựng]

---

### 📝 Từ vựng trong truyện:
- **word1**: nghĩa tiếng Việt
- **word2**: nghĩa tiếng Việt
...
''';
      return await _callAI(prompt);
    } catch (e) {
      return _handleError('generateStory', e);
    }
  }

  // ============================================
  // AI ROLEPLAY CHAT
  // ============================================

  static const Map<String, String> scenarioPrompts = {
    'restaurant': '''You are a friendly waiter at a nice restaurant called "The Golden Spoon". 
Greet the customer, present the menu, take their order, and handle payment.
Menu: Grilled Salmon (\$18), Pasta Carbonara (\$14), Caesar Salad (\$10), Steak (\$25), Lemonade (\$4), Coffee (\$3).''',

    'job_interview': '''You are a professional HR manager at a tech company called "TechVista Inc." 
conducting a job interview for a Software Developer position.
Ask questions about their experience, skills, and motivation. Be encouraging but professional.''',

    'hotel': '''You are a receptionist at "Sunrise Hotel", a 4-star beachfront hotel.
Help the guest with check-in, room selection, amenities, and local recommendations.
Rooms: Standard (\$80/night), Deluxe (\$120/night), Suite (\$200/night). All include breakfast.''',

    'shopping': '''You are a friendly sales assistant at a clothing store called "Fashion Hub".
Help the customer find clothes, suggest sizes, discuss prices, and process payment.
Current sale: 20% off on all winter items.''',

    'airport': '''You are a helpful airport staff member at the check-in counter.
Help the passenger with check-in, boarding pass, luggage rules, and gate information.
Flight details: Gate B12, boarding starts 30 minutes before departure.''',

    'doctor': '''You are a friendly doctor at a general clinic.
Listen to the patient's symptoms, ask follow-up questions, and give simple advice.
Note: Always recommend they see a real doctor for serious concerns.''',

    'free_chat': '''You are a friendly English conversation partner. 
Chat naturally about any topic the user wants. Be fun, engaging, and helpful.''',
  };

  /// Chat with AI in a roleplay scenario with grammar correction
  Future<String> chat({
    required List<Map<String, String>> messageHistory,
    required String scenario,
  }) async {
    final rateLimitMsg = _checkRateLimit();
    if (rateLimitMsg != null) return rateLimitMsg;

    try {
      _recordRequest();

      final scenarioDesc = scenarioPrompts[scenario] ?? scenarioPrompts['free_chat']!;

      final systemPrompt = '''$scenarioDesc

IMPORTANT RULES:
1. Always respond in English. Keep responses concise (2-4 sentences max).
2. Stay in character throughout the conversation.
3. If the user makes a grammar mistake, FIRST respond normally in character, THEN add a correction at the end in this exact format:
   💡 Correction: "wrong phrase" → "correct phrase" (brief explanation in Vietnamese)
4. If the user's English is perfect, do NOT add any correction.
5. Be encouraging and friendly. Use natural, everyday English.
6. If the user writes in Vietnamese, gently encourage them to try in English.''';

      // Build messages array for Qwen API
      final messages = <Map<String, String>>[
        {'role': 'system', 'content': systemPrompt},
        ...messageHistory,
      ];

      // Try Qwen first
      final qwenResult = await _callQwenChat(messages);
      if (qwenResult != null) return qwenResult;

      // Fallback: convert to single prompt for Gemini
      print('🔄 Chat fallback to Gemini...');
      final flatPrompt = StringBuffer();
      flatPrompt.writeln('System instruction: $systemPrompt\n');
      for (final msg in messageHistory) {
        final role = msg['role'] == 'user' ? 'User' : 'Assistant';
        flatPrompt.writeln('$role: ${msg['content']}');
      }
      flatPrompt.writeln('\nAssistant:');
      return await _callGemini(flatPrompt.toString());
    } catch (e) {
      return _handleError('chat', e);
    }
  }

  /// Qwen multi-turn chat API
  Future<String?> _callQwenChat(List<Map<String, String>> messages) async {
    try {
      final url = Uri.parse('${Env.qwenBaseUrl}/chat/completions');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Env.qwenApiKey}',
        },
        body: jsonEncode({
          'model': Env.qwenModel,
          'messages': messages,
          'temperature': 0.8,
          'max_tokens': 500,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'];
        if (content != null && content.toString().isNotEmpty) {
          return content.toString();
        }
      }
      print('⚠️ Qwen chat returned status ${response.statusCode}: ${response.body}');
      return null;
    } catch (e) {
      print('⚠️ Qwen chat error: $e');
      return null;
    }
  }
}

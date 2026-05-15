import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

class FeedbackService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  Future<void> submitFeedback({
    required String type, // 'bug', 'suggestion', 'wrong_word', 'other'
    required String subject,
    required String message,
    String? wordId,
    String? wordText,
  }) async {
    final user = _authService.currentUser;
    if (user == null) {
      throw Exception('Vui lòng đăng nhập để gửi phản hồi.');
    }

    final data = {
      'userId': user.uid,
      'userName': user.displayName ?? 'Người dùng',
      'userEmail': user.email ?? '',
      'type': type,
      'subject': subject,
      'message': message,
      'wordId': wordId,
      'wordText': wordText,
      'status': 'new',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      // Device info for admin debugging
      'platform': Platform.isAndroid ? 'Android' : Platform.isIOS ? 'iOS' : Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      'appVersion': '1.0.0',
    };

    await _db.collection('feedback').add(data);
  }
}

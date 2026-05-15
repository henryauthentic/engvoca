import 'package:audioplayers/audioplayers.dart';

/// Service quản lý âm thanh hiệu ứng trong app
class SoundService {
  static final SoundService instance = SoundService._init();
  SoundService._init();

  final AudioPlayer _player = AudioPlayer();

  /// Phát âm thanh khi trả lời đúng
  Future<void> playCorrect() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('audio/duolingo-correct.mp3'));
    } catch (e) {
      print('🔇 Sound error (correct): $e');
    }
  }

  /// Phát âm thanh khi trả lời sai
  Future<void> playWrong() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('audio/duolingo-wrong.mp3'));
    } catch (e) {
      print('🔇 Sound error (wrong): $e');
    }
  }

  /// Phát âm thanh khi hoàn thành bài học / phiên luyện tập
  Future<void> playCompleted() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('audio/duolingo-completed-lesson.mp3'));
    } catch (e) {
      print('🔇 Sound error (completed): $e');
    }
  }

  /// Giải phóng tài nguyên
  void dispose() {
    _player.dispose();
  }
}

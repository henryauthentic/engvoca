import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/settings_service.dart';
import '../utils/constants.dart';
import '../theme/theme_extensions.dart';

class AudioSettingsScreen extends StatefulWidget {
  const AudioSettingsScreen({super.key});

  @override
  State<AudioSettingsScreen> createState() => _AudioSettingsScreenState();
}

class _AudioSettingsScreenState extends State<AudioSettingsScreen> {
  final _settingsService = SettingsService.instance;
  final FlutterTts _flutterTts = FlutterTts();

  double _speechRate = 1.0;
  double _volume = 1.0;
  bool _autoPlay = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initTts();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
  }

  Future<void> _loadSettings() async {
    setState(() {
      _speechRate = _settingsService.getSpeechRate();
      _volume = _settingsService.getVolume();
      _autoPlay = _settingsService.getAutoPlay();
    });
  }

  Future<void> _updateSpeechRate(double value) async {
    await _settingsService.setSpeechRate(value);
    setState(() {
      _speechRate = value;
    });
  }

  Future<void> _updateVolume(double value) async {
    await _settingsService.setVolume(value);
    setState(() {
      _volume = value;
    });
  }

  Future<void> _updateAutoPlay(bool value) async {
    await _settingsService.setAutoPlay(value);
    setState(() {
      _autoPlay = value;
    });
  }

  Future<void> _testAudio() async {
    await _flutterTts.setSpeechRate(_speechRate);
    await _flutterTts.setVolume(_volume);
    await _flutterTts.speak("Hello! This is a test of the text to speech feature.");
  }

  String _getSpeechRateLabel(double rate) {
    if (rate <= 0.5) return 'Rất chậm';
    if (rate <= 0.75) return 'Chậm';
    if (rate <= 1.0) return 'Bình thường';
    if (rate <= 1.25) return 'Nhanh';
    return 'Rất nhanh';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: const Text('Âm thanh & phát âm'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        children: [
          // Speech Rate
          Card(
            elevation: isDark ? 0 : 2,
            color: context.cardColor,
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.speed,
                          color: context.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tốc độ phát âm',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _getSpeechRateLabel(_speechRate),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: context.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(
                        Icons.slow_motion_video,
                        size: 20,
                        color: context.textTertiary,
                      ),
                      Expanded(
                        child: Slider(
                          value: _speechRate,
                          min: 0.5,
                          max: 1.5,
                          divisions: 10,
                          label: '${_speechRate.toStringAsFixed(1)}x',
                          activeColor: context.primaryColor,
                          inactiveColor: isDark 
                              ? context.subtleBackground 
                              : AppConstants.primaryColor.withOpacity(0.3),
                          onChanged: _updateSpeechRate,
                        ),
                      ),
                      Icon(
                        Icons.fast_forward,
                        size: 20,
                        color: context.textTertiary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Điều chỉnh tốc độ phát âm từ 0.5x đến 1.5x',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppConstants.paddingMedium),

          // Volume
          Card(
            elevation: isDark ? 0 : 2,
            color: context.cardColor,
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.volume_up,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Âm lượng',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '${(_volume * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(
                        Icons.volume_mute,
                        size: 20,
                        color: context.textTertiary,
                      ),
                      Expanded(
                        child: Slider(
                          value: _volume,
                          min: 0.0,
                          max: 1.0,
                          divisions: 10,
                          label: '${(_volume * 100).toInt()}%',
                          activeColor: Colors.orange,
                          inactiveColor: isDark 
                              ? context.subtleBackground 
                              : Colors.orange.withOpacity(0.3),
                          onChanged: _updateVolume,
                        ),
                      ),
                      Icon(
                        Icons.volume_up,
                        size: 20,
                        color: context.textTertiary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Điều chỉnh âm lượng phát âm',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppConstants.paddingMedium),

          // Auto-play
          Card(
            elevation: isDark ? 0 : 2,
            color: context.cardColor,
            child: SwitchListTile(
              value: _autoPlay,
              onChanged: _updateAutoPlay,
              title: Text(
                'Tự động phát âm',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              subtitle: Text(
                'Tự động phát âm khi xem flashcard',
                style: TextStyle(
                  fontSize: 13,
                  color: context.textSecondary,
                ),
              ),
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _autoPlay
                      ? (AppConstants.secondaryColor).withOpacity(0.1)
                      : (context.subtleBackground),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.play_circle,
                  color: _autoPlay
                      ? (AppConstants.secondaryColor)
                      : (context.textTertiary),
                ),
              ),
              activeColor: AppConstants.secondaryColor,
            ),
          ),

          const SizedBox(height: AppConstants.paddingLarge),

          // Test Audio Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _testAudio,
              icon: const Icon(Icons.volume_up),
              label: const Text('Thử nghiệm âm thanh'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppConstants.paddingMedium),

          // Info card
          Container(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.blue.shade900.withOpacity(0.3)
                  : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              border: Border.all(
                color: isDark 
                    ? Colors.blue.shade700 
                    : Colors.blue.shade200,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cài đặt này sẽ áp dụng cho tất cả các tính năng phát âm trong ứng dụng',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark 
                          ? Colors.blue.shade100 
                          : Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
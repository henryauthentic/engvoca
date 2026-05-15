import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _playSound();
    _goNext();
  }

  Future<void> _playSound() async {
    try {
      await _audioPlayer.play(
        AssetSource('audio/splash_sound.mp3'),
        volume: 0.6,
      );
    } catch (_) {}
  }

  void _goNext() {
    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/auth');
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF5B8CFF),
                Color(0xFF6C7BFF),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),

                // =====================
                // MAIN ANIMATION (Mascot)
                // =====================
                Lottie.asset(
                  'assets/animations/splash.json',
                  width: 200,
                  repeat: true,
                ),

                const SizedBox(height: 28),

                // =====================
                // APP NAME (ĐẸP HƠN)
                // =====================
                Text(
                  'ENG VOCA',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 3,
                    shadows: [
                      Shadow(
                        offset: const Offset(0, 4),
                        blurRadius: 12,
                        color: Colors.black.withOpacity(0.25),
                      ),
                    ],
                  ),
                ).animate().fade(duration: 800.ms, delay: 200.ms).slideY(begin: 0.5, end: 0, duration: 800.ms, curve: Curves.easeOutBack),

                const SizedBox(height: 8),

                // =====================
                // SLOGAN
                // =====================
                const Text(
                  'Học từ vựng mỗi ngày',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white70,
                    letterSpacing: 0.5,
                  ),
                ),

                const Spacer(flex: 3),

                // =====================
                // LOADING (CHỈ DÙNG LOTTIE)
                // =====================
                Column(
                  children: [
                    Lottie.asset(
                      'assets/animations/loading.json',
                      width: 90, // ⭐ to hơn
                      repeat: true,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Đang khởi động...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

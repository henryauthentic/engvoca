import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import 'login_screen.dart'; // Chuyển về màn hình Login

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _authService = AuthService();
  Timer? _timer;
  bool _canResendEmail = false;
  int _countdown = 60;

  @override
  void initState() {
    super.initState();
    _startEmailVerificationCheck();
    _startResendCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startEmailVerificationCheck() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await _authService.reloadUser();
      if (_authService.isEmailVerified) {
        timer.cancel();
        if (mounted) {
          // Hiển thị thông báo thành công
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Xác thực Email thành công! 🎉 Vui lòng đăng nhập lại.'),
              backgroundColor: Colors.green, // Giống successColor
            ),
          );
          
          // Đăng xuất và điều hướng về Login
          await _authService.logout();
          
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          }
        }
      }
    });
  }

  void _startResendCountdown() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        setState(() => _canResendEmail = true);
        timer.cancel();
      }
    });
  }

  Future<void> _resendVerificationEmail() async {
    if (!_canResendEmail) return;

    try {
      await _authService.sendEmailVerification();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email xác thực đã được gửi'),
          backgroundColor: AppConstants.secondaryColor,
        ),
      );

      setState(() {
        _canResendEmail = false;
        _countdown = 60;
      });
      _startResendCountdown();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString()}'),
          backgroundColor: AppConstants.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _authService.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () async {
            await _authService.logout();
            if (mounted) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.email_outlined,
                size: 100,
                color: AppConstants.primaryColor,
              ),
              const SizedBox(height: AppConstants.paddingLarge),
              Text(
                'Xác thực Email',
                style: AppConstants.titleStyle.copyWith(fontSize: 28),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.paddingMedium),
              const Text(
                'Một email xác thực đã được gửi đến',
                style: AppConstants.subtitleStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.paddingSmall),
              Text(
                email,
                style: AppConstants.titleStyle.copyWith(
                  fontSize: 16,
                  color: AppConstants.primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.paddingLarge),
              Container(
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: AppConstants.paddingMedium),
                    Expanded(
                      child: Text(
                        'Vui lòng kiểm tra email của bạn và nhấn vào link xác thực. Trang này sẽ tự động cập nhật.',
                        style: TextStyle(color: Colors.blue[700]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.paddingLarge),
              const CircularProgressIndicator(),
              const SizedBox(height: AppConstants.paddingMedium),
              Text(
                'Đang kiểm tra trạng thái xác thực...',
                style: AppConstants.bodyStyle.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: AppConstants.paddingLarge * 2),
              TextButton(
                onPressed: _canResendEmail ? _resendVerificationEmail : null,
                child: Text(
                  _canResendEmail
                      ? 'Gửi lại email xác thực'
                      : 'Gửi lại sau $_countdown giây',
                  style: TextStyle(
                    color: _canResendEmail ? AppConstants.primaryColor : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
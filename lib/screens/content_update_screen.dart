import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import 'package:lottie/lottie.dart';
import '../models/content_update_info.dart';

class ContentUpdateScreen extends StatefulWidget {
  final ContentUpdateInfo updateInfo;

  const ContentUpdateScreen({Key? key, required this.updateInfo}) : super(key: key);

  @override
  State<ContentUpdateScreen> createState() => _ContentUpdateScreenState();
}

class _ContentUpdateScreenState extends State<ContentUpdateScreen> with SingleTickerProviderStateMixin {
  final SyncService _syncService = SyncService();
  String _statusText = 'Đang chuẩn bị dữ liệu...';
  bool _isSuccess = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
    
    _fadeController.forward();
    _startUpdate();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _startUpdate() async {
    // Delay nhẹ để user kịp đọc title
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (mounted) {
      setState(() {
        _statusText = 'Đang tải từ vựng mới...';
      });
    }

    try {
      final status = await _syncService.syncContentData(force: true);
      
      if (mounted) {
        if (status == ContentSyncStatus.success || status == ContentSyncStatus.latest) {
          setState(() {
            _statusText = 'Đang cập nhật thư viện offline...';
          });
          
          await Future.delayed(const Duration(milliseconds: 500));
          
          setState(() {
            _statusText = 'Dữ liệu học tập đã sẵn sàng!';
            _isSuccess = true;
          });
          
          // Subtle success completion delay
          await Future.delayed(const Duration(milliseconds: 1500));
          
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        } else {
          setState(() {
            _statusText = 'Có lỗi xảy ra khi cập nhật.';
          });
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.of(context).pop(false);
          }
        }
      }
    } catch (e) {
      print('Update error: $e');
      if (mounted) {
        setState(() {
          _statusText = 'Có lỗi xảy ra, vui lòng thử lại sau.';
        });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop(false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final int changedCount = widget.updateInfo.deltaWords + widget.updateInfo.deltaTopics;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Lottie hoặc Icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50,
                      shape: BoxShape.circle,
                      boxShadow: _isSuccess ? [
                        BoxShadow(
                          color: Colors.green.withOpacity(isDark ? 0.2 : 0.4),
                          blurRadius: 30,
                          spreadRadius: 10,
                        )
                      ] : null,
                    ),
                    child: _isSuccess 
                      ? const Icon(Icons.check_circle_rounded, size: 64, color: Color(0xFF10B981))
                      : const Icon(Icons.cloud_sync_rounded, size: 56, color: Color(0xFF3B82F6)),
                  ),
                  const SizedBox(height: 40),
                  
                  // Title
                  Text(
                    widget.updateInfo.title.isNotEmpty ? widget.updateInfo.title : 'Cập nhật Nội dung',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Description
                  if (changedCount > 0)
                    Text(
                      '~ $changedCount nội dung mới',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  
                  const SizedBox(height: 48),
                  
                  // Progress UI
                  if (!_isSuccess) ...[
                    SizedBox(
                      width: 200,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Status Text
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _statusText,
                      key: ValueKey<String>(_statusText),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _isSuccess 
                            ? const Color(0xFF10B981)
                            : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Một Widget đặc biệt để bọc các khối giao diện (VD: Khối Chủ đề từ vựng).
/// Khi gọi hàm `playHighlight()`, nó sẽ tạo ra một hiệu ứng nổi bạt (Micro-interaction):
/// - Scale to dần lên (1.02x)
/// - Phát ra ánh sáng mờ (Glow) màu gradient tím-xanh.
/// - Có viền bao quanh (Border) sang trọng giống iOS/Duolingo.
class PremiumHighlightCard extends StatefulWidget {
  final Widget child;
  final bool isDark;

  const PremiumHighlightCard({
    super.key,
    required this.child,
    required this.isDark,
  });

  @override
  State<PremiumHighlightCard> createState() => PremiumHighlightCardState();
}

class PremiumHighlightCardState extends State<PremiumHighlightCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Dùng mốc 1.02x thay vì 1.05x để tránh bị lẹm viền màn hình quá nhiều
    // Tạo cảm giác "thở" (soft scaling) chứ không phóng quá lố.
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _glowOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Trigger the highlight animation programmatically.
  void playHighlight() async {
    // Nếu đang chạy thì không chạy lại đè lên
    if (_controller.isAnimating) return;
    
    // 1. Phóng to & Mờ vào (Fade In & Scale Up) trong 250ms
    await _controller.animateTo(1.0, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
    
    // 2. Giữ nguyên (Stay visible) trong 1.5 giây để người dùng đọc tiêu đề
    await Future.delayed(const Duration(milliseconds: 1500));
    
    // 3. Thu nhỏ & Mờ đi (Fade Out & Scale Down) mượt mà trong 400ms
    if (mounted) {
      await _controller.animateBack(0.0, duration: const Duration(milliseconds: 400), curve: Curves.easeInCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              // Soft Glow Shadow
              boxShadow: [
                if (_glowOpacityAnimation.value > 0)
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.12 * _glowOpacityAnimation.value),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                if (_glowOpacityAnimation.value > 0)
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.08 * _glowOpacityAnimation.value),
                    blurRadius: 32,
                    spreadRadius: -4,
                  ),
              ],
            ),
            child: Stack(
              children: [
                // Lớp nội dung chính
                Container(
                  decoration: BoxDecoration(
                    // Khi highlight, đổ nền nổi lên để phân biệt với nền trang
                    color: _glowOpacityAnimation.value > 0 
                      ? (widget.isDark ? const Color(0xFF2A2A3E) : Colors.white) 
                      : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: widget.child, // Cụm Header + Danh sách từ
                ),
                
                // Lớp Overlay phủ Gradient & Border
                if (_glowOpacityAnimation.value > 0)
                  Positioned.fill(
                    child: IgnorePointer( // Không cản trở các thao tác vuốt/nhấn bên dưới
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          // Mảng màu phủ lên nội dung (Opacity siêu thấp để không làm mờ chữ)
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF8B5CF6).withOpacity(0.04 * _glowOpacityAnimation.value),
                              const Color(0xFF3B82F6).withOpacity(0.04 * _glowOpacityAnimation.value),
                            ],
                          ),
                          // Viền sáng bo quanh thẻ
                          border: Border.all(
                            color: const Color(0xFF8B5CF6).withOpacity(0.4 * _glowOpacityAnimation.value),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

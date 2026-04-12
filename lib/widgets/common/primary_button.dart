import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PrimaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final Widget? icon;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final bool isOutline;
  
  const PrimaryButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.icon,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.isOutline = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeColor = backgroundColor ?? theme.primaryColor;
    final contentColor = isOutline 
        ? themeColor 
        : (textColor ?? Colors.white);
        
    final baseStyle = ElevatedButton.styleFrom(
      backgroundColor: isOutline ? Colors.transparent : themeColor,
      foregroundColor: contentColor,
      shadowColor: themeColor.withOpacity(0.5),
      elevation: isOutline ? 0 : 4,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isOutline ? BorderSide(color: themeColor, width: 2) : BorderSide.none,
      ),
    );

    Widget child = isLoading 
        ? SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(contentColor),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                icon!,
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: contentColor,
                ),
              ),
            ],
          );

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: baseStyle,
      child: child,
    )
    .animate(target: isLoading ? 1 : 0)
    .shimmer(duration: 1000.ms, color: Colors.white24);
  }
}

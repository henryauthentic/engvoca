import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AnimatedListItem extends StatelessWidget {
  final Widget child;
  final int index;
  final double delayMultiple;

  const AnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.delayMultiple = 50.0,
  });

  @override
  Widget build(BuildContext context) {
    return child
        .animate()
        .fade(
          duration: 300.ms, 
          delay: (index * delayMultiple).ms,
        )
        .slideY(
          begin: 0.2, 
          end: 0, 
          duration: 400.ms, 
          curve: Curves.easeOutQuad,
          delay: (index * delayMultiple).ms,
        );
  }
}

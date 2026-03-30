import 'package:flutter/material.dart';

class OmniCard extends StatelessWidget {
  final Widget child;
  final Color baseColor;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final bool hasGlow;

  const OmniCard({
    super.key,
    required this.child,
    this.baseColor = Colors.white,
    this.padding = const EdgeInsets.all(12),
    this.margin = EdgeInsets.zero,
    this.hasGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: baseColor.withValues(alpha: hasGlow ? 0.3 : 0.08),
          width: 1,
        ),
        boxShadow: hasGlow
            ? [
                BoxShadow(
                  color: baseColor.withValues(alpha: 0.08),
                  blurRadius: 25,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

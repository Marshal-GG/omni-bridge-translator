import 'package:flutter/material.dart';

/// A compact label chip with a subtle tinted background and border.
///
/// Lighter than [OmniBadge] — typically used for feature tags, engine names,
/// or metadata labels. Falls back to the theme's primary color when [color]
/// is not provided.
///
/// Example:
/// ```dart
/// OmniChip(label: 'GPT-4o', color: Colors.tealAccent)
/// ```
class OmniChip extends StatelessWidget {
  /// The text label displayed inside the chip.
  final String label;

  /// The accent color for text, border, and background tint.
  final Color? color;

  /// Optional padding override.
  final EdgeInsets? padding;

  /// Optional font size override.
  final double? fontSize;

  const OmniChip({
    super.key,
    required this.label,
    this.color,
    this.padding,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? Theme.of(context).colorScheme.primary;

    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: chipColor.withValues(alpha: 0.15)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: chipColor,
          fontSize: fontSize ?? 10,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

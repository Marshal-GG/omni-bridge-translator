import 'package:flutter/material.dart';

/// A small inline status badge with a tinted background and colored border.
///
/// Typically used to label ticket status, tags, or categories with a compact
/// pill-style appearance. Text is always single-line with ellipsis overflow.
///
/// Example:
/// ```dart
/// OmniBadge(text: 'OPEN', color: Colors.tealAccent)
/// ```
class OmniBadge extends StatelessWidget {
  /// The label text displayed inside the badge.
  final String text;

  /// The accent color used for the text, border, and tinted background.
  final Color color;

  const OmniBadge({
    super.key,
    required this.text,
    this.color = Colors.blueAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

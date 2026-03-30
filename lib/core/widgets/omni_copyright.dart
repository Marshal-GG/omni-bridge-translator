import 'package:flutter/material.dart';

/// A reusable copyright text widget typically displayed at the bottom of screens or drawers.
class OmniCopyright extends StatelessWidget {
  final TextStyle? style;
  final TextAlign textAlign;

  const OmniCopyright({
    super.key,
    this.style = const TextStyle(
      color: Colors.white24,
      fontSize: 11,
    ),
    this.textAlign = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    // Dynamically fetching the current year is also an option, 
    // but we stick to the hardcoded string as per the original design for now.
    return Text(
      '© 2026 Omni Bridge. All rights reserved.',
      style: style,
      textAlign: textAlign,
    );
  }
}

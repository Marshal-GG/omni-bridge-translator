import 'package:flutter/material.dart';

/// A standardized search input for the Omni design system.
///
/// Uses the global [InputDecorationTheme] defined in [AppTheme] to ensure
/// consistent borders, fills, and focus states across the application.
class OmniSearchBar extends StatelessWidget {
  /// Localized hint text for the search input.
  final String hintText;

  /// Called whenever the user modifies the search query.
  final ValueChanged<String>? onChanged;

  /// Optional controller to manage the text externally.
  final TextEditingController? controller;

  /// Optional focus node for accessibility and programmatic focus control.
  final FocusNode? focusNode;

  /// Optional callback for when the user submits the search (e.g., presses Enter).
  final ValueChanged<String>? onSubmitted;

  const OmniSearchBar({
    super.key,
    this.hintText = 'Search...',
    this.onChanged,
    this.controller,
    this.focusNode,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search, size: 16),
        isDense: true,
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// A reusable progress bar widget that automatically handles rounded corners,
/// background styling, and optional warning colors when progress exceeds a threshold.
class OmniProgressBar extends StatelessWidget {
  /// The current progress value (clamped between 0.0 and 1.0).
  final double progress;

  /// The default color of the progress bar.
  final Color color;

  /// The background color of the track.
  final Color backgroundColor;

  /// The height of the progress bar.
  final double height;

  /// The corner radius of the progress bar.
  final double borderRadius;

  /// The threshold (0.0 to 1.0) at which the warning color applies.
  /// If null, the warning color is never applied.
  final double? warningThreshold;

  /// The color to use when [progress] is >= [warningThreshold].
  final Color warningColor;

  const OmniProgressBar({
    super.key,
    required this.progress,
    this.color = Colors.tealAccent,
    this.backgroundColor = Colors.white10,
    this.height = 4.0,
    this.borderRadius = 4.0,
    this.warningThreshold = 0.9,
    this.warningColor = Colors.redAccent,
  });

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    final isWarning = warningThreshold != null && clampedProgress >= warningThreshold!;
    final activeColor = isWarning ? warningColor : color;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: LinearProgressIndicator(
        value: clampedProgress,
        backgroundColor: backgroundColor,
        valueColor: AlwaysStoppedAnimation<Color>(activeColor),
        minHeight: height,
      ),
    );
  }
}

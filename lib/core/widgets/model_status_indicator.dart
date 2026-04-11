import 'package:flutter/material.dart';

/// Displays a badge indicating the current status of a model (Ready, Loading, Error, etc.).
/// Shared across translation and settings features.
class ModelStatusIndicator extends StatelessWidget {
  final Map<String, dynamic>? status;
  final bool compact;

  /// When true, all badge colours are forced to [Colors.white24] regardless of
  /// the actual status — used for engines that are locked or unavailable.
  final bool greyed;

  const ModelStatusIndicator({
    super.key,
    required this.status,
    this.compact = false,
    this.greyed = false,
  });

  @override
  Widget build(BuildContext context) {
    if (status == null) {
      return _badge('Offline', Colors.white24, Icons.cloud_off_rounded);
    }

    final String statusStr = status!['status'] ?? 'unknown';
    final bool ready = status!['ready'] ?? false;
    final String message = status!['message'] ?? '';
    final double progress = (status!['progress'] as num?)?.toDouble() ?? 0.0;

    switch (statusStr) {
      case 'ready':
        return _badge(
          'Ready',
          Colors.greenAccent,
          Icons.check_circle_outline_rounded,
        );
      case 'loading':
        return _badge(
          progress > 0 ? 'Loading ${(progress * 100).toInt()}%' : 'Loading...',
          Colors.orangeAccent,
          null,
          isSpinning: true,
        );
      case 'not_downloaded':
        return _badge(
          'Download needed',
          Colors.blueAccent,
          Icons.download_for_offline_rounded,
        );
      case 'no_credentials':
      case 'no_api_key':
        return _badge(
          'Validation Error/Key Missing',
          Colors.redAccent,
          Icons.key_off_rounded,
        );
      case 'fallback':
        return _badge(
          'Ready (Fallback)',
          Colors.greenAccent,
          Icons.swap_calls_rounded,
        );
      case 'error':
        return _badge(
          'Error',
          Colors.redAccent,
          Icons.error_outline_rounded,
          tooltip: message,
        );
      case 'unloaded':
        return _badge(
          'Idle',
          Colors.white38,
          Icons.hourglass_empty_rounded,
        );
      default:
        return _badge(
          ready ? 'Ready' : statusStr.toUpperCase(),
          ready ? Colors.greenAccent : Colors.white38,
          ready
              ? Icons.check_circle_outline_rounded
              : Icons.help_outline_rounded,
        );
    }
  }

  /// Applies the [greyed] override before forwarding to [_buildBadge].
  Widget _badge(
    String label,
    Color color,
    IconData? icon, {
    bool isSpinning = false,
    String? tooltip,
  }) {
    return _buildBadge(
      label,
      greyed ? Colors.white24 : color,
      icon,
      isSpinning: greyed ? false : isSpinning,
      tooltip: tooltip,
    );
  }

  Widget _buildBadge(
    String label,
    Color color,
    IconData? icon, {
    bool isSpinning = false,
    String? tooltip,
  }) {
    Widget content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 6,
        vertical: compact ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSpinning)
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
            )
          else if (icon != null)
            Icon(icon, size: 10, color: color),
          if (!compact || (icon == null && !isSpinning)) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: content);
    }
    return content;
  }
}

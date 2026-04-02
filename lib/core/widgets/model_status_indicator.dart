import 'package:flutter/material.dart';

/// Displays a badge indicating the current status of a model (Ready, Loading, Error, etc.).
/// Shared across translation and settings features.
class ModelStatusIndicator extends StatelessWidget {
  final Map<String, dynamic>? status;
  final bool compact;

  const ModelStatusIndicator({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (status == null) {
      return _buildBadge('Offline', Colors.white24, Icons.cloud_off_rounded);
    }

    final String statusStr = status!['status'] ?? 'unknown';
    final bool ready = status!['ready'] ?? false;
    final String message = status!['message'] ?? '';
    final double progress = (status!['progress'] as num?)?.toDouble() ?? 0.0;

    switch (statusStr) {
      case 'ready':
        return _buildBadge(
          'Ready',
          Colors.greenAccent,
          Icons.check_circle_outline_rounded,
        );
      case 'loading':
        return _buildBadge(
          progress > 0 ? 'Loading ${(progress * 100).toInt()}%' : 'Loading...',
          Colors.orangeAccent,
          null,
          isSpinning: true,
        );
      case 'not_downloaded':
        return _buildBadge(
          'Download needed',
          Colors.blueAccent,
          Icons.download_for_offline_rounded,
        );
      case 'no_credentials':
      case 'no_api_key':
        return _buildBadge(
          'Validation Error/Key Missing',
          Colors.redAccent,
          Icons.key_off_rounded,
        );
      case 'fallback':
        return _buildBadge(
          'Ready (Fallback)',
          Colors.greenAccent,
          Icons.swap_calls_rounded,
        );
      case 'error':
        return _buildBadge(
          'Error',
          Colors.redAccent,
          Icons.error_outline_rounded,
          tooltip: message,
        );
      case 'unloaded':
        return _buildBadge(
          'Idle',
          Colors.white38,
          Icons.hourglass_empty_rounded,
        );
      default:
        return _buildBadge(
          ready ? 'Ready' : statusStr.toUpperCase(),
          ready ? Colors.greenAccent : Colors.white38,
          ready
              ? Icons.check_circle_outline_rounded
              : Icons.help_outline_rounded,
        );
    }
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

import 'package:flutter/material.dart';

/// Displays GPU availability status with VRAM usage bar.
/// Shared across translation and settings features.
class GpuStatusIndicator extends StatelessWidget {
  final Map<String, dynamic>? status;

  const GpuStatusIndicator({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == null) return const SizedBox();

    final bool isAvailable = status!['ready'] ?? false;
    final String deviceName = status!['device_name'] ?? 'No GPU Detected';
    final double vramUsed = (status!['vram_used'] as num?)?.toDouble() ?? 0.0;
    final double vramTotal = (status!['vram_total'] as num?)?.toDouble() ?? 0.0;

    final color = isAvailable ? Colors.blueAccent : Colors.white24;
    final vramPct = vramTotal > 0
        ? (vramUsed / vramTotal).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAvailable
                    ? Icons.memory_rounded
                    : Icons.developer_board_off_rounded,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  deviceName,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isAvailable)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.blueAccent.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Text(
                    'CUDA',
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                const Text(
                  'CPU ONLY',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          if (isAvailable && vramTotal > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: vramPct,
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        vramPct > 0.85 ? Colors.redAccent : Colors.blueAccent,
                      ),
                      minHeight: 3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${vramUsed.toStringAsFixed(1)} / ${vramTotal.toStringAsFixed(1)} GB',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

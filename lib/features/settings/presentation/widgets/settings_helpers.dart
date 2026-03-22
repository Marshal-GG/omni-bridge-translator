import 'package:flutter/material.dart';

// ─── Labels ──────────────────────────────────────────────────────────────────

Widget sectionLabel(String text) {
  return Text(
    text,
    style: const TextStyle(
      color: Colors.tealAccent,
      fontWeight: FontWeight.bold,
      fontSize: 13,
    ),
  );
}

Widget sublabel(String text) {
  return Text(
    text,
    style: const TextStyle(color: Colors.white70, fontSize: 12),
  );
}

InputDecoration searchDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
    filled: true,
    fillColor: Colors.black26,
    isDense: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
  );
}

// ─── dB Meter ────────────────────────────────────────────────────────────────

Widget buildDbMeter({
  required double level,
  required String label,
  required Color color,
  required bool active,
}) {
  return Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.graphic_eq,
              size: 12,
              color: active ? color : Colors.white24,
            ),
            const SizedBox(width: 4),
            Text(
              '$label Level',
              style: TextStyle(
                color: active ? Colors.white54 : Colors.white24,
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Container(
                  height: 6,
                  width: constraints.maxWidth,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  curve: Curves.easeOut,
                  height: 6,
                  width: constraints.maxWidth * level.clamp(0.0, 1.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: level > 0.9
                          ? [Colors.redAccent, Colors.red]
                          : level > 0.6
                          ? [color, Colors.yellowAccent]
                          : [color.withValues(alpha: 0.7), color],
                    ),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: active && level > 0.02
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

// ─── Volume Slider ────────────────────────────────────────────────────────────
// Self-contained StatefulWidget so local drag state is isolated from BlocBuilder.

class VolumeSlider extends StatefulWidget {
  final String label;
  final double value;
  final Color color;
  final ValueChanged<double> onChangeEnd;
  final ValueChanged<double>? onLiveChange;

  const VolumeSlider({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.onChangeEnd,
    this.onLiveChange,
  });

  @override
  State<VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<VolumeSlider> {
  late double _localValue;

  @override
  void initState() {
    super.initState();
    _localValue = widget.value;
  }

  @override
  void didUpdateWidget(VolumeSlider old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _localValue = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = (_localValue * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.volume_up_rounded, size: 12, color: widget.color),
              const SizedBox(width: 4),
              Text(
                widget.label,
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
              const Spacer(),
              Text(
                '$pct%',
                style: TextStyle(
                  color: widget.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: widget.color,
              inactiveTrackColor: Colors.white12,
              thumbColor: widget.color,
              overlayColor: widget.color.withValues(alpha: 0.15),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: _localValue.clamp(0.0, 2.0),
              min: 0.0,
              max: 2.0,
              divisions: 40,
              onChanged: (v) {
                setState(() => _localValue = v);
                widget.onLiveChange?.call(v);
              },
              onChangeEnd: widget.onChangeEnd,
            ),
          ),
        ],
      ),
    );
  }
}
// ─── Model Status Indicator ──────────────────────────────────────────────────

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

// ─── GPU Status Indicator ────────────────────────────────────────────────────

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
        borderRadius: BorderRadius.circular(8),
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

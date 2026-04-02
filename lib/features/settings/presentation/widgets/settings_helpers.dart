import 'package:flutter/material.dart';

// Re-export shared widgets from core so existing imports still work.
export 'package:omni_bridge/core/widgets/model_status_indicator.dart';
export 'package:omni_bridge/core/widgets/gpu_status_indicator.dart';

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
      borderRadius: BorderRadius.circular(6),
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


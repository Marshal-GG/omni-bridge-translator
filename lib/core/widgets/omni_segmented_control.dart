import 'package:flutter/material.dart';

/// A segmented pill-style control bar, consistent with the Omni widget system.
///
/// Each segment can have an optional [icon] and a required [label].
/// The selected segment gets a tinted background + colored border glow.
///
/// Example:
/// ```dart
/// OmniSegmentedControl<String>(
///   value: _selected,
///   color: Colors.tealAccent,
///   segments: const [
///     OmniSegment(value: 'a', label: 'Option A', icon: Icons.bolt),
///     OmniSegment(value: 'b', label: 'Option B', icon: Icons.star),
///   ],
///   onChanged: (v) => setState(() => _selected = v),
/// );
/// ```
class OmniSegment<T> {
  final T value;
  final String label;
  final IconData? icon;

  const OmniSegment({required this.value, required this.label, this.icon});
}

class OmniSegmentedControl<T> extends StatelessWidget {
  final T value;
  final List<OmniSegment<T>> segments;
  final ValueChanged<T> onChanged;

  /// The accent color used for selected segment highlight and borders.
  final Color color;

  const OmniSegmentedControl({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
    this.color = Colors.tealAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: segments.map((seg) {
          final isSelected = seg.value == value;
          return Expanded(
            child: _OmniSegmentTile(
              label: seg.label,
              icon: seg.icon,
              isSelected: isSelected,
              color: color,
              onTap: () => onChanged(seg.value),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _OmniSegmentTile extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _OmniSegmentTile({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
    this.icon,
  });

  @override
  State<_OmniSegmentTile> createState() => _OmniSegmentTileState();
}

class _OmniSegmentTileState extends State<_OmniSegmentTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.isSelected ? widget.color : Colors.white54;
    final bgAlpha = widget.isSelected ? 0.12 : (_hovered ? 0.04 : 0.0);
    final borderAlpha = widget.isSelected ? 0.35 : 0.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: bgAlpha),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.color.withValues(alpha: borderAlpha),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 13, color: activeColor),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: activeColor,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

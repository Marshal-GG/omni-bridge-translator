import 'package:flutter/material.dart';

/// A translucent tinted action button consistent with the Omni design system.
///
/// Renders a tinted background from [color] with a matching label and optional
/// leading [icon]. Supports a loading spinner state, hover scale animation,
/// and a border that appears on hover. Disabled automatically when
/// [onPressed] is `null` or [isLoading] is `true`.
///
/// Example:
/// ```dart
/// OmniTintedButton(
///   label: 'Submit',
///   icon: Icons.send_rounded,
///   color: AppColors.accentCyan,
///   onPressed: _submit,
/// )
/// ```
class OmniTintedButton extends StatefulWidget {
  /// The label text displayed on the button.
  final String label;

  /// Optional leading icon. Pass `null` to render a label-only button.
  final IconData? icon;

  /// The accent color used for the background tint, text, and icon.
  final Color color;

  /// The action to perform when tapped. Pass `null` to disable the button.
  final VoidCallback? onPressed;

  /// When `true`, replaces the icon with a [CircularProgressIndicator]
  /// and disables interaction.
  final bool isLoading;

  /// The opacity multiplier for the background tint. Defaults to `0.15`.
  final double alpha;

  const OmniTintedButton({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.alpha = 0.15,
  });

  @override
  State<OmniTintedButton> createState() => _OmniTintedButtonState();
}

class _OmniTintedButtonState extends State<OmniTintedButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;
    final effectiveColor = isDisabled ? Colors.white38 : widget.color;
    final bgColor = effectiveColor.withValues(alpha: widget.alpha);
    final hoverColor = effectiveColor.withValues(alpha: widget.alpha + 0.1);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: (_isHovered && !isDisabled) ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: ElevatedButton.icon(
          onPressed: widget.isLoading ? null : widget.onPressed,
          icon: widget.isLoading
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
                  ),
                )
              : (widget.icon != null
                    ? Icon(widget.icon, size: 16)
                    : const SizedBox.shrink()),
          label: Text(
            widget.label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isHovered && !isDisabled ? hoverColor : bgColor,
            foregroundColor: effectiveColor,
            elevation: 0,
            shadowColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: BorderSide(
                color: effectiveColor.withValues(alpha: _isHovered ? 0.3 : 0.0),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

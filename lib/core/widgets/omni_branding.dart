import 'package:flutter/material.dart';

import 'package:omni_bridge/core/widgets/omni_chip.dart';

/// A reusable branding header used across different screens in the application.
class OmniBranding extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData fallbackIcon;
  final double logoSize;
  final Widget? bottomWidget;

  /// When `true`, renders the subtitle as an [OmniChip] instead of plain text.
  final bool subtitleAsChip;

  /// The accent color for the chip when [subtitleAsChip] is `true`.
  /// Defaults to [Colors.tealAccent] if not specified.
  final Color? subtitleChipColor;

  /// Controls horizontal alignment of the branding row contents.
  final MainAxisAlignment mainAxisAlignment;

  const OmniBranding({
    super.key,
    this.title = 'Omni Bridge',
    required this.subtitle,
    required this.fallbackIcon,
    this.logoSize = 56.0,
    this.bottomWidget,
    this.subtitleAsChip = false,
    this.subtitleChipColor,
    this.mainAxisAlignment = MainAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      children: [
        Image.asset(
          'assets/app/icons/icon.png',
          width: logoSize,
          height: logoSize,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
              return Container(
                width: logoSize,
                height: logoSize,
                color: Colors.white10,
                child: Icon(
                  fallbackIcon,
                  color: Colors.tealAccent,
                  size: logoSize * 0.57,
                ),
              );
            },
          ),
        const SizedBox(width: 16),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              if (subtitleAsChip)
                OmniChip(
                  label: subtitle.toUpperCase(),
                  color: subtitleChipColor ?? Colors.tealAccent,
                  fontSize: 8,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                )
              else
                Text(
                  subtitle.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.tealAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (bottomWidget != null) ...[
                const SizedBox(height: 12),
                bottomWidget!,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

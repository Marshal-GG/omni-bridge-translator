import 'package:flutter/material.dart';

/// A reusable branding header used across different screens in the application.
class OmniBranding extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData fallbackIcon;
  final double logoSize;
  final Widget? bottomWidget;

  const OmniBranding({
    super.key,
    this.title = 'Omni Bridge',
    required this.subtitle,
    required this.fallbackIcon,
    this.logoSize = 56.0,
    this.bottomWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/app/icons/icon.png',
            width: logoSize,
            height: logoSize,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: logoSize,
                height: logoSize,
                color: Colors.white10,
                child: Icon(
                  fallbackIcon,
                  color: Colors.tealAccent,
                  size: logoSize * 0.57, // scale icon size based on logo size
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        Column(
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
            ),
            Text(
              subtitle.toUpperCase(),
              style: const TextStyle(
                color: Colors.tealAccent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            if (bottomWidget != null) ...[
              const SizedBox(height: 12),
              bottomWidget!,
            ],
          ],
        ),
      ],
    );
  }
}

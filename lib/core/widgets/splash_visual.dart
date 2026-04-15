import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:omni_bridge/core/theme/app_theme.dart';

/// Pure visual layer of the splash screen.
/// Used by [SplashScreen] (real boot) and the About screen test preview.
///
/// [draggable] wraps the centre area with [MoveWindow] so the real splash
/// window is draggable. Set to false (default) when embedding in a dialog.
class SplashVisual extends StatelessWidget {
  final Animation<double> pulseAnimation;
  final String statusText;
  final bool isIndeterminate;
  final double progressValue;
  final bool draggable;

  const SplashVisual({
    super.key,
    required this.pulseAnimation,
    this.statusText = 'Starting up...',
    this.isIndeterminate = true,
    this.progressValue = 0.0,
    this.draggable = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget center = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ScaleTransition(
          scale: pulseAnimation,
          child: Image.asset(
            'assets/app/icons/icon.png',
            width: 96,
            height: 96,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Omni Bridge',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          statusText,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );

    if (draggable) {
      center = WindowTitleBarBox(child: MoveWindow(child: center));
    }

    return Container(
      color: AppColors.bgDeep,
      child: Column(
        children: [
          Expanded(child: center),
          Padding(
            padding: const EdgeInsets.only(left: 32, right: 32, bottom: 40),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 6,
                child: isIndeterminate
                    ? const LinearProgressIndicator(
                        backgroundColor: AppColors.bgElevated,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.accentCyan,
                        ),
                      )
                    : LinearProgressIndicator(
                        value: progressValue,
                        backgroundColor: AppColors.bgElevated,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.accentCyan,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

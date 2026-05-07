import 'package:flutter/material.dart';

import 'package:omni_bridge/core/di/di.dart';
import 'package:omni_bridge/core/theme/app_theme.dart';
import 'package:omni_bridge/features/subscription/domain/repositories/i_subscription_repository.dart';

class BottomTrialCta extends StatefulWidget {
  final bool trialUsed;

  const BottomTrialCta({super.key, required this.trialUsed});

  @override
  State<BottomTrialCta> createState() => _BottomTrialCtaState();
}

class _BottomTrialCtaState extends State<BottomTrialCta> {
  bool _loading = false;

  Future<void> _activate() async {
    if (widget.trialUsed || _loading) return;
    setState(() => _loading = true);
    final err = await sl<ISubscriptionRepository>().activateTrial();
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: AppColors.accentRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.trialUsed || _loading;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.semanticAsr.withValues(alpha: 0.10),
            AppColors.teal(0.10),
            AppColors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: AppShapes.lg,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.trialUsed
                      ? 'You\'ve used your free trial.'
                      : 'Not sure yet? Try Pro free for 24 hours.',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'No card required. Once per account. Auto-expires — we’ll '
                  'never charge you without asking.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          ElevatedButton(
            onPressed: disabled ? null : _activate,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amberAccent,
              foregroundColor: AppColors.black,
              disabledBackgroundColor: AppColors.white(0.06),
              disabledForegroundColor: AppColors.textDisabled,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(borderRadius: AppShapes.md),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            child: _loading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.black,
                    ),
                  )
                : Text(
                    widget.trialUsed ? 'Trial Used' : 'Start 24h Trial →',
                  ),
          ),
        ],
      ),
    );
  }
}

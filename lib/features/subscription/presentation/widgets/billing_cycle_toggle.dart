import 'package:flutter/material.dart';

import 'package:omni_bridge/core/theme/app_theme.dart';

import '../bloc/subscription_state.dart';

class BillingCycleToggle extends StatelessWidget {
  final BillingCycle value;
  final ValueChanged<BillingCycle> onChanged;

  const BillingCycleToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: AppShapes.md,
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CycleTile(
            label: 'Monthly',
            isSelected: value == BillingCycle.monthly,
            onTap: () => onChanged(BillingCycle.monthly),
          ),
          _CycleTile(
            label: 'Yearly',
            isSelected: value == BillingCycle.yearly,
            onTap: () => onChanged(BillingCycle.yearly),
            trailing: _DiscountPill(
              label: '-27%',
              parentSelected: value == BillingCycle.yearly,
            ),
          ),
        ],
      ),
    );
  }
}

class _CycleTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget? trailing;

  const _CycleTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.teal(0.12)
                : AppColors.transparent,
            borderRadius: AppShapes.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? AppColors.accentTeal
                      : AppColors.textMuted,
                  letterSpacing: 0.2,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 6),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscountPill extends StatelessWidget {
  final String label;
  final bool parentSelected;

  const _DiscountPill({required this.label, required this.parentSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: parentSelected ? AppColors.accentTeal : AppColors.teal(0.25),
        borderRadius: AppShapes.sm,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: parentSelected ? AppColors.black : AppColors.accentTeal,
        ),
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:omni_bridge/core/di/di.dart';
import '../bloc/subscription_bloc.dart';
import '../bloc/subscription_event.dart';
import '../bloc/subscription_state.dart';
import '../widgets/billing_cycle_toggle.dart';
import '../widgets/bottom_trial_cta.dart';
import '../widgets/plan_card.dart';
import '../widgets/plan_compare_table.dart';
import '../widgets/plan_faq_section.dart';
import '../widgets/trust_panel.dart';
import 'package:omni_bridge/core/widgets/omni_version_chip.dart';
import '../widgets/subscription_header.dart';
import 'package:omni_bridge/features/shell/presentation/widgets/app_dashboard_shell.dart';
import 'package:omni_bridge/core/navigation/app_router.dart';
import 'package:omni_bridge/core/utils/duration_utils.dart';
import 'package:omni_bridge/features/subscription/domain/repositories/i_subscription_repository.dart';
import 'package:omni_bridge/features/subscription/data/datasources/subscription_remote_datasource.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _DebugTierPanel extends StatelessWidget {
  const _DebugTierPanel();

  @override
  Widget build(BuildContext context) {
    final src = sl<SubscriptionRemoteDataSource>();
    final tiers = sl<ISubscriptionRepository>().tierOrder;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Text(
            'DEBUG — Tier Switcher',
            style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: tiers.map((t) => OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontSize: 11),
              ),
              onPressed: () => t == 'trial'
                  ? src.activateFreshTrialDebug()
                  : src.setTierDebug(t),
              child: Text(t),
            )).toList(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orangeAccent,
                  side: const BorderSide(color: Colors.orangeAccent),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 11),
                ),
                onPressed: () => src.activateExpiredTrialDebug(),
                child: const Text('Set trial → already expired'),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.greenAccent,
                  side: const BorderSide(color: Colors.greenAccent),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 11),
                ),
                onPressed: () => src.resetTrialDebug(),
                child: const Text('Reset trial'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  final _formatter = NumberFormat('#,###');

  @override
  Widget build(BuildContext context) {
    return AppDashboardShell(
      currentRoute: AppRouter.subscription,
      header: buildSubscriptionHeader(context),
      child: BlocProvider(
        create: (context) => sl<SubscriptionBloc>(),
        child: BlocBuilder<SubscriptionBloc, SubscriptionState>(
          builder: (context, state) {
            final status = state.status;
            final plans = state.plans;
            final isLoading = state.isLoading && plans.isEmpty;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeroBlock(
                        cycle: state.billingCycle,
                        onCycleChanged: (cycle) => context
                            .read<SubscriptionBloc>()
                            .add(SubscriptionBillingCycleChanged(cycle)),
                        onManageBilling: () => Navigator.of(context)
                            .pushReplacementNamed(AppRouter.billing),
                      ),
                      const SizedBox(height: 24),
                      if (isLoading)
                        const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.tealAccent,
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: plans.map((plan) {
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7.0,
                                    ),
                                    child: buildPlanCard(
                                      plan: plan,
                                      isCurrent: status?.tier == plan.id,
                                      trialUsed: state.trialUsed,
                                      billingCycle: state.billingCycle,
                                      formatter: _formatter,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      if (status?.tier == 'trial' &&
                          status?.trialExpiresAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.timer_outlined,
                                size: 13,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                formatTimeRemaining(status!.trialExpiresAt!),
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 36),
                      PlanCompareTable(
                        plans: plans,
                        formatter: _formatter,
                      ),
                      const SizedBox(height: 32),
                      const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: PlanFaqSection()),
                          SizedBox(width: 22),
                          Expanded(flex: 2, child: TrustPanel()),
                        ],
                      ),
                      const SizedBox(height: 28),
                      BottomTrialCta(trialUsed: state.trialUsed),
                      const SizedBox(height: 32),
                      const Center(child: OmniVersionChip()),
                      const SizedBox(height: 16),
                      if (kDebugMode) _DebugTierPanel(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeroBlock extends StatelessWidget {
  final BillingCycle cycle;
  final ValueChanged<BillingCycle> onCycleChanged;
  final VoidCallback onManageBilling;

  const _HeroBlock({
    required this.cycle,
    required this.onCycleChanged,
    required this.onManageBilling,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Plans & Pricing',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'One trial, one Pro tier, one Enterprise tier — built for daily real-time translation.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.end,
          children: [
            BillingCycleToggle(value: cycle, onChanged: onCycleChanged),
            OutlinedButton.icon(
              onPressed: onManageBilling,
              icon: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 14,
              ),
              label: const Text('Manage Billing'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

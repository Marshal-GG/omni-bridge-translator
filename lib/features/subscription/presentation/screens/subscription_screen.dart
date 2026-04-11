import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:omni_bridge/core/di/di.dart';
import '../bloc/subscription_bloc.dart';
import '../bloc/subscription_state.dart';
import '../widgets/plan_card.dart';
import '../widgets/section_title.dart';
import 'package:omni_bridge/core/widgets/omni_version_chip.dart';
import '../widgets/subscription_header.dart';
import 'package:omni_bridge/features/shell/presentation/widgets/app_dashboard_shell.dart';
import 'package:omni_bridge/core/navigation/app_router.dart';
import 'package:omni_bridge/core/utils/duration_utils.dart';
import 'package:omni_bridge/features/subscription/data/datasources/subscription_remote_datasource.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _DebugTierPanel extends StatelessWidget {
  final _src = SubscriptionRemoteDataSource.instance;

  _DebugTierPanel();

  @override
  Widget build(BuildContext context) {
    final tiers = _src.tierOrder;
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
                  ? _src.activateFreshTrialDebug()
                  : _src.setTierDebug(t),
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
                onPressed: () => _src.activateExpiredTrialDebug(),
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
                onPressed: () => _src.resetTrialDebug(),
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
        child: Column(
          children: [
            Expanded(
              child: BlocBuilder<SubscriptionBloc, SubscriptionState>(
                builder: (context, state) {
                  final status = state.status;
                  final plans = state.plans;

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 24,
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight - 48,
                              minWidth: constraints.maxWidth - 48,
                            ),
                            child: Center(
                              child: SizedBox(
                                width: 900,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 24,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.03,
                                        ),
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.05,
                                          ),
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          buildSectionTitle(
                                            title: 'Subscription Plans',
                                            subtitle:
                                                'Select a plan that fits your needs. Upgrade anytime.',
                                          ),
                                          const SizedBox(height: 24),
                                          if (state.isLoading && plans.isEmpty)
                                            const Center(
                                              child: Padding(
                                                padding: EdgeInsets.all(32.0),
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Colors.tealAccent,
                                                    ),
                                              ),
                                            )
                                          else
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: plans.map((plan) {
                                                return Expanded(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8.0,
                                                        ),
                                                    child: buildPlanCard(
                                                      plan: plan,
                                                      isCurrent:
                                                          status?.tier ==
                                                          plan.id,
                                                      trialUsed:
                                                          state.trialUsed,
                                                      formatter: _formatter,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          if (status?.tier == 'trial' &&
                                              status?.trialExpiresAt != null)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 16),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const Icon(Icons.timer_outlined, size: 13, color: Colors.amber),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    formatTimeRemaining(status!.trialExpiresAt!),
                                                    style: const TextStyle(color: Colors.amber, fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                    const OmniVersionChip(),
                                    const SizedBox(height: 16),
                                    if (kDebugMode) _DebugTierPanel(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

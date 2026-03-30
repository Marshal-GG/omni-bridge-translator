import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:omni_bridge/core/di/injection.dart';
import '../bloc/subscription_bloc.dart';
import '../bloc/subscription_state.dart';
import '../widgets/info_card.dart';
import '../widgets/plan_card.dart';
import '../widgets/section_title.dart';
import 'package:omni_bridge/core/widgets/omni_version_chip.dart';
import '../widgets/subscription_header.dart';
import '../widgets/subscription_footer.dart';
import 'package:omni_bridge/core/widgets/omni_branding.dart';
import '../widgets/current_usage_display.dart';
import 'package:omni_bridge/core/widgets/omni_window_layout.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
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
    return OmniWindowLayout(
      child: BlocProvider(
        create: (context) => sl<SubscriptionBloc>(),
            child: Column(
              children: [
                buildSubscriptionHeader(context),
                const Divider(height: 1, color: Colors.white10),
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
                                    width: 1020,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const OmniBranding(
                                          subtitle: 'PREMIUM SUBSCRIPTION',
                                          fallbackIcon: Icons.workspace_premium_rounded,
                                        ),
                                        const SizedBox(height: 24),
                                        if (status != null) ...[
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                            ),
                                            child: buildInfoCard(
                                              icon: Icons.data_usage_rounded,
                                              title: 'Current Usage',
                                              child: buildCurrentUsageDisplay(
                                                status: status,
                                                formatter: _formatter,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 24),
                                        ],
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 24,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.03,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
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
                                              if (state.isLoading &&
                                                  plans.isEmpty)
                                                const Center(
                                                  child: Padding(
                                                    padding: EdgeInsets.all(
                                                      32.0,
                                                    ),
                                                    child:
                                                        CircularProgressIndicator(
                                                          color:
                                                              Colors.tealAccent,
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
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 32),
                                        buildSubscriptionFooter(context),
                                        const SizedBox(height: 24),
                                        const OmniVersionChip(),
                                        const SizedBox(height: 16),
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

import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:intl/intl.dart';
import '../../core/services/subscription_service.dart';

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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WindowBorder(
        color: Colors.white12,
        width: 1,
        child: Container(
          color: const Color(0xFF121212),
          child: Column(
            children: [
              _buildHeader(context),
              const Divider(height: 1, color: Colors.white10),
              Expanded(
                child: StreamBuilder<SubscriptionStatus>(
                  stream: SubscriptionService.instance.statusStream,
                  builder: (context, snapshot) {
                    final status =
                        snapshot.data ??
                        SubscriptionService.instance.currentStatus;
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 32,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight:
                                  constraints.maxHeight -
                                  64, // Subtracting vertical padding
                            ),
                            child: Center(
                              child: SizedBox(
                                width: 1040,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    _buildBranding(),
                                    const SizedBox(height: 24),
                                    if (status != null) ...[
                                      _InfoCard(
                                        icon: Icons.data_usage_rounded,
                                        title: 'Current Usage',
                                        child: _buildCurrentUsage(status),
                                      ),
                                      const SizedBox(height: 24),
                                    ],
                                    const _SectionTitle(
                                      title: 'Subscription Plans',
                                      subtitle:
                                          'Select a plan that fits your needs. Upgrade anytime.',
                                    ),
                                    const SizedBox(height: 24),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        _PlanCard(
                                          tier: SubscriptionTier.free,
                                          name: 'Free',
                                          price: '₹0',
                                          description: 'For occasional use',
                                          features: const [
                                            '10,000 Chars Daily',
                                            'Standard Engines',
                                            'Basic Live Captions',
                                          ],
                                          isCurrent:
                                              status?.tier ==
                                              SubscriptionTier.free,
                                          formatter: _formatter,
                                        ),
                                        const SizedBox(width: 20),
                                        _PlanCard(
                                          tier: SubscriptionTier.weekly,
                                          name: 'Weekly',
                                          price: '₹49',
                                          period: '/wk',
                                          description: 'For short trips',
                                          features: const [
                                            '50,000 Chars Daily',
                                            'Same-Session History',
                                            'High-Speed Translation',
                                            'Standard Live Captions',
                                          ],
                                          isCurrent:
                                              status?.tier ==
                                              SubscriptionTier.weekly,
                                          formatter: _formatter,
                                        ),
                                        const SizedBox(width: 20),
                                        _PlanCard(
                                          tier: SubscriptionTier.plus,
                                          name: 'Plus',
                                          price: '₹149',
                                          period: '/mo',
                                          description: 'For active learners',
                                          features: const [
                                            '100,000 Chars Daily',
                                            '3-Day History Access',
                                            'Advanced Live Captions',
                                            'Priority Support',
                                            'Offline Model Support',
                                          ],
                                          isCurrent:
                                              status?.tier ==
                                              SubscriptionTier.plus,
                                          isPopular: true,
                                          formatter: _formatter,
                                        ),
                                        const SizedBox(width: 20),
                                        _PlanCard(
                                          tier: SubscriptionTier.pro,
                                          name: 'Pro',
                                          price: '₹399',
                                          period: '/mo',
                                          description: 'For power users',
                                          features: const [
                                            'Unlimited Daily Chars',
                                            'Intelligent Context Refresh (5s)',
                                            'Unlimited History Access',
                                            'Premium Translation Engines',
                                            '24/7 Priority Support',
                                          ],
                                          isCurrent:
                                              status?.tier ==
                                              SubscriptionTier.pro,
                                          formatter: _formatter,
                                        ),
                                      ],
                                    ),
                                  ],
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
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                size: 15,
                color: Colors.white38,
              ),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              splashRadius: 16,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.workspace_premium_rounded,
            size: 14,
            color: Colors.white38,
          ),
          const SizedBox(width: 8),
          const Text(
            'Subscription Plans',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(child: MoveWindow()),
          MinimizeWindowButton(
            colors: WindowButtonColors(iconNormal: Colors.white38),
          ),
          CloseWindowButton(
            colors: WindowButtonColors(
              iconNormal: Colors.white38,
              mouseOver: Colors.redAccent,
            ),
            onPressed: () => appWindow.close(),
          ),
        ],
      ),
    );
  }

  Widget _buildBranding() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.asset(
            'assets/icon.png',
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 56,
                height: 56,
                color: Colors.white10,
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.tealAccent,
                  size: 32,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Omni Bridge',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'PREMIUM SUBSCRIPTION',
              style: TextStyle(
                color: Colors.tealAccent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCurrentUsage(SubscriptionStatus status) {
    if (status.tier == SubscriptionTier.pro) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.teal.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.2)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: Colors.tealAccent,
              size: 16,
            ),
            SizedBox(width: 8),
            Text(
              'PRO UNLIMITED ACCESS ACTIVE',
              style: TextStyle(
                color: Colors.tealAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Daily Quota Usage',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              '${(status.progress * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.tealAccent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: status.progress,
            backgroundColor: Colors.white10,
            color: status.progress > 0.9 ? Colors.redAccent : Colors.tealAccent,
            minHeight: 5,
          ),
        ),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.white38, fontSize: 10),
            children: [
              TextSpan(
                text: _formatter.format(status.dailyCharsUsed),
                style: const TextStyle(
                  color: Colors.tealAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text:
                    ' / ${_formatter.format(status.dailyLimit)} characters used',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.white38, fontSize: 13),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: Colors.tealAccent),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionTier tier;
  final String name;
  final String price;
  final String? period;
  final String description;
  final List<String> features;
  final bool isCurrent;
  final bool isPopular;
  final NumberFormat formatter;

  const _PlanCard({
    required this.tier,
    required this.name,
    required this.price,
    this.period,
    required this.description,
    required this.features,
    this.isCurrent = false,
    this.isPopular = false,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isPopular
            ? const Color(0xFF1A1A1A)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPopular
              ? Colors.tealAccent.withValues(alpha: 0.4)
              : Colors.white10,
          width: isPopular ? 1.5 : 1,
        ),
        boxShadow: isPopular
            ? [
                BoxShadow(
                  color: Colors.tealAccent.withValues(alpha: 0.05),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isPopular)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.tealAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.tealAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Text(
                    'POPULAR',
                    style: TextStyle(
                      color: Colors.tealAccent,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (period != null)
                Text(
                  period!,
                  style: const TextStyle(color: Colors.white38, fontSize: 14),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          const SizedBox(height: 20),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.tealAccent,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isCurrent
                  ? null
                  : () => SubscriptionService.instance.openCheckout(tier),
              style: ElevatedButton.styleFrom(
                backgroundColor: isPopular ? Colors.tealAccent : Colors.white10,
                foregroundColor: isPopular ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.05),
              ),
              child: Text(
                isCurrent ? 'Current Plan' : 'Select Plan',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

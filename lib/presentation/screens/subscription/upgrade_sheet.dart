import 'package:flutter/material.dart';
import 'package:omni_bridge/data/services/firebase/subscription_service.dart';
import 'package:omni_bridge/presentation/screens/subscription/subscription_screen.dart';

void showUpgradeSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => const UpgradeSheet(),
  );
}

class UpgradeSheet extends StatelessWidget {
  const UpgradeSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final plans = SubscriptionService.instance.availablePlans;
    final promptConfig = SubscriptionService.instance.upgradePromptConfig;
    final title = promptConfig?['feature_locked']?['title'] as String? ?? 'Upgrade Your Plan';
    final message = promptConfig?['feature_locked']?['message'] as String? ??
        'Get more daily tokens and unlock exclusive features like premium translation engines.';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rocket_launch, color: Colors.teal, size: 28),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 24),
          // Show highlights from each paid plan (skip the first/free tier)
          ...plans.where((p) => p.id != SubscriptionService.instance.defaultTier).map((plan) {
            final highlight = plan.isUnlimited
                ? '${plan.name}: Unlimited usage & ${plan.allowedTranslationModels.length} engines'
                : '${plan.name}: ${plan.features.isNotEmpty ? plan.features.first : plan.description}';
            return _buildFeatureRow(
              plan.isPopular ? Icons.auto_awesome_rounded : Icons.bolt_rounded,
              highlight,
            );
          }),
          // Extra highlights from Firestore upgrade_prompts config
          ...((promptConfig?['feature_locked']?['highlights'] as List<dynamic>?) ?? [])
              .map((h) => _buildFeatureRow(Icons.contact_support_rounded, h.toString())),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SubscriptionScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'View Plans',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.tealAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

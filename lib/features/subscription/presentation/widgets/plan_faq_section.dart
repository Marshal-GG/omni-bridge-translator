import 'package:flutter/material.dart';

import 'package:omni_bridge/core/theme/app_theme.dart';

class PlanFaqSection extends StatefulWidget {
  const PlanFaqSection({super.key});

  @override
  State<PlanFaqSection> createState() => _PlanFaqSectionState();
}

class _PlanFaqSectionState extends State<PlanFaqSection> {
  static const List<_FaqItem> _items = [
    _FaqItem(
      'How does the 24-hour trial work?',
      'You get one trial per account. The moment you activate it, you have '
          '24 hours of full Pro access — every engine, every language, full '
          'history. After 24h your account drops to Free until you subscribe.',
    ),
    _FaqItem(
      'What happens when I hit the daily limit?',
      'Translation pauses for the rest of the day. Your daily counter resets '
          'at midnight UTC; your monthly counter resets on your billing date. '
          'Live transcription continues working — only translation tokens are '
          'metered.',
    ),
    _FaqItem(
      'Can I cancel any time?',
      'Yes. Cancellation is processed by Razorpay — your access stays active '
          'until the end of the current billing period, then your account '
          'moves to Free. You can re-subscribe at the same plan whenever you '
          'want.',
    ),
    _FaqItem(
      'What if a payment fails?',
      'Razorpay retries the renewal automatically. If every retry fails the '
          'subscription is halted and your account is downgraded — you\'ll '
          'see a "Payment Failed" banner on the Billing screen with a '
          'one-tap re-subscribe.',
    ),
    _FaqItem(
      'Do tokens roll over?',
      'No. Both the daily and monthly buckets reset on schedule and unused '
          'tokens don\'t carry forward. Plans are sized so heavy users on '
          'Pro don\'t typically run out.',
    ),
    _FaqItem(
      'Can I bring my own NVIDIA NIM key?',
      'Enterprise plans can paste a personal NIM key in Settings → Languages '
          'and route Llama/Riva calls through their own quota. Pro and Free '
          'use the shared Omni Bridge endpoints.',
    ),
  ];

  int _openIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FREQUENTLY ASKED',
          style: TextStyle(
            color: AppColors.accentCyan.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < _items.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _FaqTile(
            item: _items[i],
            isOpen: i == _openIndex,
            onToggle: () =>
                setState(() => _openIndex = _openIndex == i ? -1 : i),
          ),
        ],
      ],
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem(this.question, this.answer);
}

class _FaqTile extends StatelessWidget {
  final _FaqItem item;
  final bool isOpen;
  final VoidCallback onToggle;

  const _FaqTile({
    required this.item,
    required this.isOpen,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isOpen ? AppColors.white(0.02) : null,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.question,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    AnimatedRotation(
                      turns: isOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: isOpen
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Text(
                      item.answer,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.6,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

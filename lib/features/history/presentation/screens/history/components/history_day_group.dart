import 'package:flutter/material.dart';

import 'package:omni_bridge/core/theme/app_theme.dart';

/// Header above a group of entries that share a day label
/// (Today / Yesterday / N days ago / weekday + month).
class HistoryDayGroup extends StatelessWidget {
  final String label;
  final int count;
  final List<Widget> children;

  const HistoryDayGroup({
    required this.label,
    required this.count,
    required this.children,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.textDisabled,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Divider(color: AppColors.white10, height: 1),
                ),
                const SizedBox(width: 10),
                Text(
                  '$count ${count == 1 ? 'entry' : 'entries'}',
                  style: const TextStyle(
                    color: AppColors.textFaint,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

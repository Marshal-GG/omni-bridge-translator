import 'package:flutter/material.dart';
import 'package:omni_bridge/features/usage/domain/entities/daily_usage_record.dart';

class UsageHistoryChart extends StatelessWidget {
  final List<DailyUsageRecord> history;

  const UsageHistoryChart({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No usage data available for the last 30 days',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
      );
    }

    final maxTokens = history.fold<int>(
      0,
      (max, e) => e.totalTokens > max ? e.totalTokens : max,
    );
    final displayMax = maxTokens == 0 ? 1000 : (maxTokens * 1.2).toInt();

    return SizedBox(
      height: 200,
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: history.map((record) {
                final heightFactor = record.totalTokens / displayMax;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Tooltip(
                      message:
                          '${record.date.month}/${record.date.day}: ${record.totalTokens} tokens',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: (heightFactor * 150).clamp(4.0, 150.0),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.tealAccent.withValues(alpha: 0.8),
                                  Colors.teal.withValues(alpha: 0.2),
                                ],
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${history.first.date.month}/${history.first.date.day}',
                style: const TextStyle(color: Colors.white38, fontSize: 9),
              ),
              const Text(
                'Last 30 Days',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${history.last.date.month}/${history.last.date.day}',
                style: const TextStyle(color: Colors.white38, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

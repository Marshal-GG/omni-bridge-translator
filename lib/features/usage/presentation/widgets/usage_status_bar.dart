import 'package:flutter/material.dart';
import 'package:omni_bridge/core/theme/app_theme.dart';

/// 28 px footer matching `demo/Usage Analytics.html` StatusBar.
///
/// Shows three status dots (translation engine · ASR engine · data connection)
/// using real engine names from the loaded state, plus "Updated Ns ago".
class UsageStatusBar extends StatefulWidget {
  final DateTime loadedAt;
  final int avgLatencyMs;
  final String translationEngine;
  final String transcriptionEngine;
  final bool isConnected;

  const UsageStatusBar({
    super.key,
    required this.loadedAt,
    this.avgLatencyMs = 0,
    this.translationEngine = '',
    this.transcriptionEngine = '',
    this.isConnected = true,
  });

  @override
  State<UsageStatusBar> createState() => _UsageStatusBarState();
}

class _UsageStatusBarState extends State<UsageStatusBar> {
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _tick();
  }

  void _tick() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _now = DateTime.now());
        _tick();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final diff = _now.difference(widget.loadedAt);
    final updatedStr = _formatAgo(diff);

    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (widget.translationEngine.isNotEmpty) ...[
            _StatusDot(
              color: UsageColors.translationAccent,
              label: widget.translationEngine.toUpperCase(),
            ),
            const SizedBox(width: 14),
          ],
          if (widget.transcriptionEngine.isNotEmpty) ...[
            _StatusDot(
              color: UsageColors.asrAccent,
              label: widget.transcriptionEngine.toUpperCase(),
            ),
            const SizedBox(width: 14),
          ],
          _StatusDot(
            color: widget.isConnected ? AppColors.accentTeal : UsageColors.errorRed,
            label: widget.isConnected ? 'LIVE' : 'OFFLINE',
          ),
          const Spacer(),
          if (widget.avgLatencyMs > 0) ...[
            Text(
              '${widget.avgLatencyMs}ms latency',
              style: const TextStyle(
                color: AppColors.textFaint,
                fontSize: 10,
                fontFamily: 'JetBrains Mono',
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '·',
              style: TextStyle(
                color: AppColors.textFaint,
                fontSize: 10,
                fontFamily: 'JetBrains Mono',
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            updatedStr,
            style: const TextStyle(
              color: AppColors.textFaint,
              fontSize: 10,
              fontFamily: 'JetBrains Mono',
            ),
          ),
        ],
      ),
    );
  }

  String _formatAgo(Duration d) {
    if (d.inSeconds < 5) return 'Updated just now';
    if (d.inMinutes < 1) return 'Updated ${d.inSeconds}s ago';
    if (d.inHours < 1) return 'Updated ${d.inMinutes}m ago';
    return 'Updated ${d.inHours}h ago';
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;
  final String label;

  const _StatusDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            boxShadow: [BoxShadow(color: color, blurRadius: 6)],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            fontFamily: 'JetBrains Mono',
          ),
        ),
      ],
    );
  }
}

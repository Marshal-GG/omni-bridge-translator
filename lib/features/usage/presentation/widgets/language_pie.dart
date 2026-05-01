import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:omni_bridge/core/theme/app_theme.dart';
import 'package:omni_bridge/features/usage/domain/entities/language_usage.dart';

/// SVG-style donut chart showing the top source languages by token share.
/// Empty state shows a prompt until data is available.
class LanguagePie extends StatelessWidget {
  final List<LanguageUsage> languages;

  const LanguagePie({super.key, required this.languages});

  static const _palette = [
    UsageColors.translationAccent,
    UsageColors.asrAccent,
    AppColors.amber,
    AppColors.splashBlue,
    AppColors.pink,
    AppColors.textDisabled,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      height: 280,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Languages',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: languages.isEmpty
                ? _EmptyState()
                : _PieContent(
                    languages: languages,
                    palette: _palette,
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Donut + legend ────────────────────────────────────────────────────────────

class _PieContent extends StatelessWidget {
  final List<LanguageUsage> languages;
  final List<Color> palette;

  const _PieContent({required this.languages, required this.palette});

  @override
  Widget build(BuildContext context) {
    // Cap at top 5 + "Other"
    final top = languages.take(5).toList();
    final rest = languages.skip(5).toList();
    final otherTokens = rest.fold<int>(0, (s, l) => s + l.tokens);

    final items = <_PieItem>[
      for (int i = 0; i < top.length; i++)
        _PieItem(
          code: top[i].code,
          tokens: top[i].tokens,
          color: palette[i % palette.length],
        ),
      if (otherTokens > 0)
        _PieItem(
          code: 'other',
          tokens: otherTokens,
          color: palette[5 % palette.length],
        ),
    ];

    final total = items.fold<int>(0, (s, e) => s + e.tokens);
    if (total == 0) return _EmptyState();

    return Row(
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: CustomPaint(
            painter: _DonutPainter(items: items, total: total),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${items.length}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'JetBrains Mono',
                    ),
                  ),
                  const Text(
                    'LANGS',
                    style: TextStyle(
                      color: AppColors.textFaint,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: items.map((item) {
              final pct = (item.tokens / total * 100);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: item.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _flagFor(item.code),
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _displayName(item.code),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${pct.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontFamily: 'JetBrains Mono',
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  static String _flagFor(String code) {
    const flags = {
      'en': '🇬🇧', 'es': '🇪🇸', 'fr': '🇫🇷', 'de': '🇩🇪', 'ja': '🇯🇵',
      'zh': '🇨🇳', 'ko': '🇰🇷', 'pt': '🇧🇷', 'it': '🇮🇹', 'ru': '🇷🇺',
      'ar': '🇸🇦', 'hi': '🇮🇳', 'nl': '🇳🇱', 'sv': '🇸🇪', 'pl': '🇵🇱',
      'tr': '🇹🇷', 'uk': '🇺🇦', 'vi': '🇻🇳', 'th': '🇹🇭', 'id': '🇮🇩',
      'other': '🌐',
    };
    return flags[code.toLowerCase()] ?? '🌐';
  }

  static String _displayName(String code) {
    const names = {
      'en': 'English', 'es': 'Spanish', 'fr': 'French', 'de': 'German',
      'ja': 'Japanese', 'zh': 'Chinese', 'ko': 'Korean', 'pt': 'Portuguese',
      'it': 'Italian', 'ru': 'Russian', 'ar': 'Arabic', 'hi': 'Hindi',
      'nl': 'Dutch', 'sv': 'Swedish', 'pl': 'Polish', 'tr': 'Turkish',
      'uk': 'Ukrainian', 'vi': 'Vietnamese', 'th': 'Thai', 'id': 'Indonesian',
      'other': 'Other',
    };
    if (code == 'other') return 'Other';
    return names[code.toLowerCase()] ?? code.toUpperCase();
  }
}

class _PieItem {
  final String code;
  final int tokens;
  final Color color;
  const _PieItem({
    required this.code,
    required this.tokens,
    required this.color,
  });

  @override
  bool operator ==(Object other) =>
      other is _PieItem &&
      other.code == code &&
      other.tokens == tokens &&
      other.color == color;

  @override
  int get hashCode => Object.hash(code, tokens, color);
}

// ── Donut painter ─────────────────────────────────────────────────────────────

class _DonutPainter extends CustomPainter {
  final List<_PieItem> items;
  final int total;

  const _DonutPainter({required this.items, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = math.min(cx, cy) * 0.85;
    final innerR = r * 0.55;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    double start = -math.pi / 2;
    for (final item in items) {
      final sweep = (item.tokens / total) * 2 * math.pi;
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()
          ..color = item.color
          ..style = PaintingStyle.fill,
      );
      // Stroke separator
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()
          ..color = AppColors.bgDeep
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      start += sweep;
    }

    // Inner circle (donut hole)
    canvas.drawCircle(
      Offset(cx, cy),
      innerR,
      Paint()..color = AppColors.bgDeep,
    );
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      !listEquals(old.items, items) || old.total != total;
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.language_rounded,
            size: 28,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 8),
          Text(
            'Start translating to see\nlanguage breakdown',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.25),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:omni_bridge/core/di/di.dart';
import 'package:omni_bridge/core/theme/app_theme.dart';
import 'package:omni_bridge/features/subscription/domain/entities/subscription_plan.dart';
import 'package:omni_bridge/features/subscription/domain/repositories/i_subscription_repository.dart';

/// Data-driven feature comparison table.
///
/// Quota rows + engine rows are read from [plans] (source of truth =
/// `monetization_config` in Firestore). A small set of marketing rows
/// (translation history, custom NIM key, admin panel, priority support)
/// are hardcoded per tier id since they're not in the domain entity.
///
/// Collapses to the first [_collapsedRowCount] rows by default with a
/// Show more / Show less toggle.
class PlanCompareTable extends StatefulWidget {
  final List<SubscriptionPlan> plans;
  final NumberFormat formatter;

  const PlanCompareTable({
    super.key,
    required this.plans,
    required this.formatter,
  });

  static const int _collapsedRowCount = 5;

  @override
  State<PlanCompareTable> createState() => _PlanCompareTableState();
}

class _PlanCompareTableState extends State<PlanCompareTable> {
  bool _expanded = false;

  static const Map<String, _ColSpec> _tierSpec = {
    'free': _ColSpec('FREE', AppColors.textSecondary),
    'trial': _ColSpec('TRIAL', Colors.amberAccent),
    'pro': _ColSpec('PRO', AppColors.accentTeal),
    'enterprise': _ColSpec('ENTERPRISE', AppColors.splashPurple),
  };

  // Marketing rows that aren't in SubscriptionPlan — keyed by tier id.
  static const Map<String, Map<String, Object>> _marketingRows = {
    'Translation history': {
      'free': '50 entries',
      'trial': 'Unlimited',
      'pro': 'Unlimited',
      'enterprise': 'Unlimited',
    },
    'Custom NIM key': {
      'free': false,
      'trial': false,
      'pro': false,
      'enterprise': true,
    },
    'Admin panel': {
      'free': false,
      'trial': false,
      'pro': false,
      'enterprise': true,
    },
    'Priority support': {
      'free': false,
      'trial': false,
      'pro': true,
      'enterprise': 'Dedicated · SLA',
    },
  };

  @override
  Widget build(BuildContext context) {
    final plans = widget.plans;
    if (plans.isEmpty) return const SizedBox.shrink();

    final repo = sl<ISubscriptionRepository>();

    final cols = plans
        .map(
          (p) =>
              _tierSpec[p.id] ??
              _ColSpec(p.name.toUpperCase(), AppColors.textSecondary),
        )
        .toList();

    final rows = <_RowData>[];

    // Quota rows — data-driven
    rows.add(
      _RowData(
        'Monthly tokens',
        plans.map((p) => _formatTokens(p.monthlyTokens)).toList(),
      ),
    );
    rows.add(
      _RowData(
        'Daily tokens',
        plans.map((p) => _formatTokens(p.dailyTokens)).toList(),
      ),
    );
    rows.add(
      _RowData(
        'Requests / minute',
        plans.map((p) => p.requestsPerMinute.toString()).toList(),
      ),
    );
    rows.add(
      _RowData(
        'Concurrent sessions',
        plans.map((p) => p.concurrentSessions.toString()).toList(),
      ),
    );

    // Translation engine rows — union across all plans, cap from engineLimits.
    final translationEngines = <String>{};
    for (final p in plans) {
      translationEngines.addAll(p.allowedTranslationModels);
    }
    for (final engine in translationEngines) {
      rows.add(
        _RowData(
          repo.getModelDisplayName(engine),
          plans.map((p) => _engineCell(p, engine)).toList(),
        ),
      );
    }

    // ASR engine rows — collapse whisper variants to a single row.
    final asrEngines = <String>{};
    for (final p in plans) {
      asrEngines.addAll(_collapseWhisperModels(p.allowedTranscriptionModels));
    }
    for (final engine in asrEngines) {
      final label = engine == 'whisper'
          ? 'Whisper (all variants)'
          : repo.getModelDisplayName(engine);
      rows.add(
        _RowData(
          label,
          plans.map((p) {
            final collapsed = _collapseWhisperModels(
              p.allowedTranscriptionModels,
            );
            return collapsed.contains(engine);
          }).toList(),
        ),
      );
    }

    // Marketing rows — hardcoded per tier id
    for (final entry in _marketingRows.entries) {
      rows.add(
        _RowData(
          entry.key,
          plans.map((p) => entry.value[p.id] ?? false).toList(),
        ),
      );
    }

    final canCollapse = rows.length > PlanCompareTable._collapsedRowCount;
    final visibleRows = canCollapse && !_expanded
        ? rows.sublist(0, PlanCompareTable._collapsedRowCount)
        : rows;
    final hiddenCount = rows.length - visibleRows.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'COMPARE EVERY FEATURE',
              style: TextStyle(
                color: AppColors.accentTeal.withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              '${rows.length} features · ${cols.length} tiers',
              style: const TextStyle(
                color: AppColors.textDisabled,
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: AppShapes.lg,
            border: Border.all(color: AppColors.cardBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _HeaderRow(cols: cols),
              for (var i = 0; i < visibleRows.length; i++)
                _DataRow(
                  row: visibleRows[i],
                  cols: cols,
                  isLast: i == visibleRows.length - 1 && !canCollapse,
                  zebra: i.isOdd,
                ),
              if (canCollapse)
                _ToggleRow(
                  expanded: _expanded,
                  hiddenCount: hiddenCount,
                  onTap: () => setState(() => _expanded = !_expanded),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTokens(int n) {
    if (n < 0) return '∞';
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(n % 1000000 == 0 ? 0 : 1)}M';
    }
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K';
    }
    return widget.formatter.format(n);
  }

  Object _engineCell(SubscriptionPlan plan, String engine) {
    if (!plan.allowedTranslationModels.contains(engine)) return false;
    final cap = plan.engineLimits[engine];
    if (cap == null || cap <= 0) return true;
    return '${_formatTokens(cap)}/mo';
  }
}

class _ToggleRow extends StatelessWidget {
  final bool expanded;
  final int hiddenCount;
  final VoidCallback onTap;

  const _ToggleRow({
    required this.expanded,
    required this.hiddenCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.cardBorder)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                expanded
                    ? 'Show less'
                    : 'Show $hiddenCount more feature${hiddenCount == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: AppColors.accentTeal,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: AppColors.accentTeal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColSpec {
  final String name;
  final Color color;
  const _ColSpec(this.name, this.color);
}

class _RowData {
  final String label;
  final List<Object> values;
  const _RowData(this.label, this.values);
}

class _HeaderRow extends StatelessWidget {
  final List<_ColSpec> cols;

  const _HeaderRow({required this.cols});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(
        children: [
          const Expanded(
            flex: 16,
            child: Text(
              'FEATURE',
              style: TextStyle(
                color: AppColors.textDisabled,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          for (final c in cols)
            Expanded(
              flex: 10,
              child: Center(
                child: Text(
                  c.name,
                  style: TextStyle(
                    color: c.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final _RowData row;
  final List<_ColSpec> cols;
  final bool isLast;
  final bool zebra;

  const _DataRow({
    required this.row,
    required this.cols,
    required this.isLast,
    required this.zebra,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: BoxDecoration(
        color: zebra ? AppColors.white(0.012) : null,
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 16,
            child: Text(
              row.label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          for (var i = 0; i < cols.length && i < row.values.length; i++)
            Expanded(
              flex: 10,
              child: Center(
                child: _CellValue(value: row.values[i], color: cols[i].color),
              ),
            ),
        ],
      ),
    );
  }
}

class _CellValue extends StatelessWidget {
  final Object value;
  final Color color;

  const _CellValue({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    if (value is bool) {
      if (value as bool) {
        return Icon(Icons.check_rounded, size: 16, color: color);
      }
      return const Text(
        '—',
        style: TextStyle(color: AppColors.textFaint, fontSize: 14),
      );
    }
    return Text(
      value.toString(),
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

List<String> _collapseWhisperModels(List<String> models) {
  final result = <String>[];
  var whisperAdded = false;
  for (final m in models) {
    if (m.startsWith('whisper-')) {
      if (!whisperAdded) {
        result.add('whisper');
        whisperAdded = true;
      }
    } else {
      result.add(m);
    }
  }
  return result;
}

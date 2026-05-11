import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class _PillSizing {
  final double labelFontSize;
  final double valueFontSize;
  final double paddingV;
  final double paddingH;
  final double borderRadius;
  final double gap;
  final double wrapSpacing;

  const _PillSizing({
    required this.labelFontSize,
    required this.valueFontSize,
    required this.paddingV,
    required this.paddingH,
    required this.borderRadius,
    required this.gap,
    required this.wrapSpacing,
  });
}

const _compactSizing = _PillSizing(
  labelFontSize: 8,
  valueFontSize: 11,
  paddingV: 5,
  paddingH: 10,
  borderRadius: 6,
  gap: 5,
  wrapSpacing: 6,
);

const _normalSizing = _PillSizing(
  labelFontSize: 11,
  valueFontSize: 16,
  paddingV: 8,
  paddingH: 14,
  borderRadius: 8,
  gap: 7,
  wrapSpacing: 8,
);

/// Summary pills row: Time, Avg W, Avg HR, Max HR.
/// Natural sizing, space-evenly, wrap to new rows.
class HudSummaryPills extends StatelessWidget {
  final String elapsed;
  final String avgPower;
  final String avgHr;
  final String maxHr;
  final bool compact;

  const HudSummaryPills({
    super.key,
    required this.elapsed,
    required this.avgPower,
    required this.avgHr,
    required this.maxHr,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final sizing = compact ? _compactSizing : _normalSizing;
    return Wrap(
      spacing: sizing.wrapSpacing,
      runSpacing: sizing.wrapSpacing,
      alignment: WrapAlignment.spaceEvenly,
      children: [
        _Pill(label: 'Time', value: elapsed, sizing: sizing),
        _Pill(label: 'Avg W', value: avgPower, sizing: sizing),
        _Pill(label: 'Avg HR', value: avgHr, sizing: sizing),
        _Pill(label: 'Max HR', value: maxHr, sizing: sizing),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final String value;
  final _PillSizing sizing;

  const _Pill({
    required this.label,
    required this.value,
    required this.sizing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: sizing.paddingV,
        horizontal: sizing.paddingH,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.borderLight, width: 2),
        borderRadius: BorderRadius.circular(sizing.borderRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: sizing.labelFontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: AppColors.muted,
            ),
          ),
          SizedBox(width: sizing.gap),
          Text(
            value,
            style: TextStyle(
              fontSize: sizing.valueFontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
              color: AppColors.dark,
            ),
          ),
        ],
      ),
    );
  }
}

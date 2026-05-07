import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Summary pills row: Time, Avg W, Avg HR, Max HR.
/// Natural sizing, space-evenly, wrap to new rows.
class HudSummaryPills extends StatelessWidget {
  final String elapsed;
  final String avgPower;
  final String avgHr;
  final String maxHr;

  const HudSummaryPills({
    super.key,
    required this.elapsed,
    required this.avgPower,
    required this.avgHr,
    required this.maxHr,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.spaceEvenly,
      children: [
        _Pill(label: 'Time', value: elapsed),
        _Pill(label: 'Avg W', value: avgPower),
        _Pill(label: 'Avg HR', value: avgHr),
        _Pill(label: 'Max HR', value: maxHr),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final String value;

  const _Pill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.borderLight, width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
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

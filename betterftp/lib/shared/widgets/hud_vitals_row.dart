import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// HR + Cadence row with colored icon boxes, side-by-side.
class HudVitalsRow extends StatelessWidget {
  final int? heartRate;
  final int cadence;

  const HudVitalsRow({
    super.key,
    required this.heartRate,
    required this.cadence,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        children: [
          // Heart rate cell
          Expanded(
            child: _VitalCell(
              icon: '♥',
              iconBg: AppColors.hrBg,
              value: heartRate != null ? '$heartRate' : '--',
              label: 'Heart Rate • BPM',
            ),
          ),
          // Vertical divider
          Container(width: 2, color: AppColors.borderLight),
          // Cadence cell
          Expanded(
            child: _VitalCell(
              icon: '⟳',
              iconBg: AppColors.cadenceBg,
              value: '$cadence',
              label: 'Cadence • RPM',
            ),
          ),
        ],
      ),
    );
  }
}

class _VitalCell extends StatelessWidget {
  final String icon;
  final Color iconBg;
  final String value;
  final String label;

  const _VitalCell({
    required this.icon,
    required this.iconBg,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Row(
        children: [
          // Icon box
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBg,
              border: Border.all(color: AppColors.dark, width: 2.5),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(icon, style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 12),
          // Data column
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  color: AppColors.dark,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

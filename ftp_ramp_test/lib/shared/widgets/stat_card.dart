import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum StatCardType { power, hr, cadence, speed }

class StatCard extends StatelessWidget {
  final StatCardType type;
  final String value;
  final String unit;

  const StatCard({
    super.key,
    required this.type,
    required this.value,
    required this.unit,
  });

  Color get _headerBg => switch (type) {
        StatCardType.power => AppColors.teal,
        StatCardType.hr => AppColors.pink,
        StatCardType.cadence => AppColors.tealDark,
        StatCardType.speed => AppColors.dark,
      };

  String get _label => switch (type) {
        StatCardType.power => 'POWER',
        StatCardType.hr => 'HEART RATE',
        StatCardType.cadence => 'CADENCE',
        StatCardType.speed => 'SPEED',
      };

  String get _icon => switch (type) {
        StatCardType.power => '\u26A1',
        StatCardType.hr => '\u2665',
        StatCardType.cadence => '\u27F3',
        StatCardType.speed => '\u25CE',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.dark, width: 3),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
            color: _headerBg,
            child: Row(
              children: [
                Text(
                  _icon,
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
                const SizedBox(width: 5),
                Text(
                  _label,
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // Body
          Container(
            color: AppColors.card,
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    height: 1,
                    color: AppColors.dark,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  unit.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.muted,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

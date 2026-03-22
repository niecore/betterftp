import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Power zone: large 72px watts, target label (top-left), delta badge (top-right).
class HudPowerSection extends StatelessWidget {
  final int currentPower;
  final int targetPower;

  const HudPowerSection({
    super.key,
    required this.currentPower,
    required this.targetPower,
  });

  @override
  Widget build(BuildContext context) {
    final delta = currentPower - targetPower;
    final deltaStr = delta >= 0 ? '+$delta' : '$delta';
    final isOver = delta >= 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderLight, width: 2),
        ),
      ),
      child: Stack(
        children: [
          // Center: large power value
          Center(
            child: Column(
              children: [
                Text(
                  '$currentPower',
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -3,
                    color: AppColors.dark,
                    height: 0.85,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'WATTS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),

          // Top-left: target label
          Positioned(
            top: 0,
            left: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TARGET',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppColors.muted,
                  ),
                ),
                Text(
                  '${targetPower}W',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: AppColors.teal,
                  ),
                ),
              ],
            ),
          ),

          // Top-right: delta badge
          if (targetPower > 0)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 3,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: isOver ? AppColors.tealBg : AppColors.pinkBg,
                  border: Border.all(
                    color: isOver ? AppColors.teal : AppColors.pink,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  deltaStr,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: isOver ? AppColors.teal : AppColors.pink,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

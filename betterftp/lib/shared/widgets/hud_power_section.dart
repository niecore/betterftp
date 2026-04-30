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
    // Compact mode for small phones (iPhone SE, iPhone mini line) — keeps
    // the HUD legible while reclaiming ~24pt of vertical space.
    // 825 catches iPhone 13 mini (812) but not regular iPhone 13 (844).
    final isCompact = MediaQuery.sizeOf(context).height < 825;
    final delta = currentPower - targetPower;
    final deltaStr = delta >= 0 ? '+$delta' : '$delta';
    final isOver = delta >= 0;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        isCompact ? 14 : 20,
        20,
        isCompact ? 10 : 16,
      ),
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
                  style: TextStyle(
                    fontSize: isCompact ? 56 : 72,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -3,
                    color: AppColors.dark,
                    height: 0.85,
                  ),
                ),
                SizedBox(height: isCompact ? 2 : 4),
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

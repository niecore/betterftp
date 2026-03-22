import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Stepped workout progress footer: each block = one stage.
/// States: done (teal), current (teal-bg outline), future (0.35 opacity).
class HudSteppedProgress extends StatelessWidget {
  final int totalStages;
  final int currentStage; // 1-based stage number

  const HudSteppedProgress({
    super.key,
    required this.totalStages,
    required this.currentStage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.borderLight, width: 2),
        ),
      ),
      child: Column(
        children: [
          // Label row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TEST PROGRESS',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: AppColors.muted,
                ),
              ),
              Text(
                'Stage $currentStage / $totalStages',
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: AppColors.dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          // Stepped blocks
          SizedBox(
            height: 10,
            child: Row(
              children: List.generate(totalStages, (i) {
                final stageIndex = i; // 0-based
                final isDone = stageIndex < currentStage - 1;
                final isCurrent = stageIndex == currentStage - 1;
                final isFuture = stageIndex > currentStage - 1;

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i > 0 ? 2 : 0),
                    child: _StepBlock(
                      isDone: isDone,
                      isCurrent: isCurrent,
                      isFuture: isFuture,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepBlock extends StatelessWidget {
  final bool isDone;
  final bool isCurrent;
  final bool isFuture;

  const _StepBlock({
    required this.isDone,
    required this.isCurrent,
    required this.isFuture,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color borderColor;

    if (isDone) {
      bgColor = AppColors.teal;
      borderColor = AppColors.tealDark;
    } else if (isCurrent) {
      bgColor = AppColors.tealBg;
      borderColor = AppColors.teal;
    } else {
      bgColor = const Color(0xFFE8E5E0);
      borderColor = const Color(0xFFCCCCCC);
    }

    return Opacity(
      opacity: isFuture ? 0.35 : 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 1.5),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

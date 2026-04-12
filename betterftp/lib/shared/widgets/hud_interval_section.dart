import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Interval section: Done/Left times + 20-segment progress bar.
class HudIntervalSection extends StatelessWidget {
  final int elapsedSeconds;
  final int remainingSeconds;
  final int totalDuration;
  final int numSegments;

  const HudIntervalSection({
    super.key,
    required this.elapsedSeconds,
    required this.remainingSeconds,
    required this.totalDuration,
    this.numSegments = 20,
  });

  String _fmtShort(int s) {
    final clamped = s.clamp(0, 99999);
    final m = clamped ~/ 60;
    final sec = clamped % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderLight, width: 2),
        ),
      ),
      child: Column(
        children: [
          // Done / Left times
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TimeBlock(
                label: 'Done',
                value: _fmtShort(elapsedSeconds),
                isMuted: true,
              ),
              _TimeBlock(
                label: 'Left',
                value: _fmtShort(remainingSeconds),
                isMuted: false,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Segmented bar
          _SegmentBar(
            numSegments: numSegments,
            elapsed: elapsedSeconds,
            total: totalDuration,
          ),
        ],
      ),
    );
  }
}

class _TimeBlock extends StatelessWidget {
  final String label;
  final String value;
  final bool isMuted;

  const _TimeBlock({
    required this.label,
    required this.value,
    required this.isMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
            color: isMuted ? AppColors.muted : AppColors.dark,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _SegmentBar extends StatelessWidget {
  final int numSegments;
  final int elapsed;
  final int total;

  const _SegmentBar({
    required this.numSegments,
    required this.elapsed,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? (elapsed / total).clamp(0.0, 1.0) : 0.0;
    final filledCount = (fraction * numSegments).floor();
    final partialIdx = filledCount;
    final partialPct =
        (fraction * numSegments - filledCount).clamp(0.0, 1.0);

    return SizedBox(
      height: 14,
      child: Row(
        children: List.generate(numSegments, (i) {
          final isDone = i < filledCount;
          final isActive = i == partialIdx && i < numSegments;
          final isFuture = i > partialIdx;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i > 0 ? 3 : 0),
              child: _Segment(
                isDone: isDone,
                isActive: isActive,
                isFuture: isFuture,
                fillFraction: isActive ? partialPct : 0,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final bool isDone;
  final bool isActive;
  final bool isFuture;
  final double fillFraction;

  const _Segment({
    required this.isDone,
    required this.isActive,
    required this.isFuture,
    required this.fillFraction,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDone ? AppColors.teal : const Color(0xFFE8E5E0);
    final borderColor = isDone
        ? AppColors.tealDark
        : isActive
            ? AppColors.teal
            : AppColors.dark;
    final opacity = isFuture ? 0.3 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 2),
          borderRadius: BorderRadius.circular(3),
        ),
        clipBehavior: Clip.hardEdge,
        child: isActive
            ? FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fillFraction,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.teal,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
